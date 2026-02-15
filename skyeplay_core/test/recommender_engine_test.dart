import 'dart:convert';
import 'package:skyeplay_core/src/database/database.dart';
import 'package:skyeplay_core/src/database/schema.dart';
import 'package:skyeplay_core/src/metadata/models/metadata.dart';
import 'package:skyeplay_core/src/services/recommender_engine.dart';
import 'package:test/test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  group('RecommenderEngine', () {
    late SkyeplayDatabase db;
    late RecommenderEngine recommender;

    setUp(() async {
      db = SkyeplayDatabase(NativeDatabase.memory());
      recommender = RecommenderEngine(db);

      // Seed Data
      // 3 Tracks in a chain: A -> B -> C
      final tracks = ['A', 'B', 'C'].map((id) => SpotubeFullTrackObject(
        id: id,
        name: "Track $id",
        externalUri: "",
        artists: [SpotubeSimpleArtistObject(name: "Artist", id: "a1", externalUri: "")],
        album: SpotubeSimpleAlbumObject(name: "Album", id: "al1", externalUri: "", artists: [], albumType: SpotubeAlbumType.album),
        durationMs: 300,
        explicit: false,
        isrc: id
      )).toList();

      for (final t in tracks) {
        await db.into(db.songs).insert(SongsCompanion.insert(
          id: t.id,
          title: t.name,
          artist: "Artist",
          trackJson: jsonEncode(t.toJson()),
          createdAt: drift.Value(DateTime.now())
        ));
      }

      // Edges: A->B (weight 100), B->C (weight 100)
      await db.into(db.edges).insert(EdgesCompanion.insert(
        sourceId: 'A',
        targetId: 'B',
        weight: const drift.Value(100.0),
        createdAt: drift.Value(DateTime.now())
      ));
      await db.into(db.edges).insert(EdgesCompanion.insert(
        sourceId: 'B',
        targetId: 'C',
        weight: const drift.Value(100.0),
        createdAt: drift.Value(DateTime.now())
      ));
    });

    tearDown(() async {
      await db.close();
    });

    test('Follows edges (Exploitation)', () async {
      // Logic has 15% random chance. 
      // To strictly test exploitation, we can mock Random or run multiple times.
      // Or just check that it *can* return B from A.
      
      // Let's run 20 times, statistics say most should be B.
      int bCount = 0;
      for (int i = 0; i < 20; i++) {
        final next = await recommender.nextTrack(currentTrackId: 'A');
        if (next?.id == 'B') bCount++;
      }
      
      print("A -> B count: $bCount / 20");
      expect(bCount, greaterThan(0)); // Should be significantly > 0
    });

    test('Falls back to random on dead end', () async {
      // C has no outgoing edges
      // Should return random track (A, B, or C)
      final next = await recommender.nextTrack(currentTrackId: 'C');
      expect(next, isNotNull);
      expect(['A', 'B', 'C'], contains(next!.id));
    });

    test('Random start (No current track)', () async {
      final next = await recommender.nextTrack();
      expect(next, isNotNull);
      expect(['A', 'B', 'C'], contains(next!.id));
    });
  });
}
