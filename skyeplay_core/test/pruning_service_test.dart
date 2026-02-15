import 'dart:io';
import 'dart:convert';
import 'package:skyeplay_core/src/database/database.dart';
import 'package:skyeplay_core/src/database/schema.dart';
import 'package:skyeplay_core/src/metadata/models/metadata.dart';
import 'package:skyeplay_core/src/services/pruning_service.dart';
import 'package:test/test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  group('PruningService', () {
    late SkyeplayDatabase db;
    late PruningService pruner;
    late Directory tempDir;

    setUp(() async {
      db = SkyeplayDatabase(NativeDatabase.memory());
      tempDir = await Directory.systemTemp.createTemp('skyeplay_prune_test');
      pruner = PruningService(db, maxSongsWithFiles: 3); // Low quota for testing
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    Future<void> insertSong(String id, {double score = 0.0, String? filePath}) async {
      final track = SpotubeFullTrackObject(
        id: id, name: "Track $id", externalUri: "",
        artists: [SpotubeSimpleArtistObject(name: "Artist", id: "a1", externalUri: "")],
        album: SpotubeSimpleAlbumObject(name: "Album", id: "al1", externalUri: "", artists: [], albumType: SpotubeAlbumType.album),
        durationMs: 300, explicit: false, isrc: id,
      );
      await db.into(db.songs).insert(SongsCompanion.insert(
        id: id, title: "Track $id", artist: "Artist",
        trackJson: jsonEncode(track.toJson()),
        score: drift.Value(score),
        filePath: drift.Value(filePath),
        createdAt: drift.Value(DateTime.now()),
      ));
    }

    test('Does nothing when under quota', () async {
      await insertSong("s1", filePath: "f1");
      await insertSong("s2", filePath: "f2");

      final pruned = await pruner.prune();
      expect(pruned, equals(0));
    });

    test('Prunes lowest-scored songs over quota', () async {
      // Create real files
      for (int i = 1; i <= 5; i++) {
        final f = File('${tempDir.path}/track$i.mp3');
        await f.create();
        await insertSong("s$i", score: i.toDouble(), filePath: f.path);
      }

      // 5 songs, quota 3 => prune 2 lowest (s1=1.0, s2=2.0)
      final pruned = await pruner.prune();
      expect(pruned, equals(2));

      // Verify files deleted
      expect(await File('${tempDir.path}/track1.mp3').exists(), isFalse);
      expect(await File('${tempDir.path}/track2.mp3').exists(), isFalse);
      expect(await File('${tempDir.path}/track3.mp3').exists(), isTrue);

      // Verify songs still in DB but filePath cleared
      final s1 = await (db.select(db.songs)..where((s) => s.id.equals("s1"))).getSingle();
      expect(s1.filePath, isNull);

      final s3 = await (db.select(db.songs)..where((s) => s.id.equals("s3"))).getSingle();
      expect(s3.filePath, isNotNull);
    });

    test('Preserves pinned songs (score > 100)', () async {
      for (int i = 1; i <= 5; i++) {
        final f = File('${tempDir.path}/pinned$i.mp3');
        await f.create();
        // s1 and s2 are pinned (score > 100)
        await insertSong("p$i", score: i <= 2 ? 200.0 : i.toDouble(), filePath: f.path);
      }

      // 5 songs, quota 3 => prune 2. But s1/s2 are pinned.
      // So prune s3=3.0 and s4=4.0 (lowest non-pinned)
      final pruned = await pruner.prune();
      expect(pruned, equals(2));

      // Pinned files still exist
      expect(await File('${tempDir.path}/pinned1.mp3').exists(), isTrue);
      expect(await File('${tempDir.path}/pinned2.mp3').exists(), isTrue);

      // Non-pinned lowest pruned
      expect(await File('${tempDir.path}/pinned3.mp3').exists(), isFalse);
      expect(await File('${tempDir.path}/pinned4.mp3').exists(), isFalse);
      expect(await File('${tempDir.path}/pinned5.mp3').exists(), isTrue);
    });
  });
}
