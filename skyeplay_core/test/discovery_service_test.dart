import 'dart:io';
import 'dart:convert';
import 'package:skyeplay_core/src/database/database.dart';
import 'package:skyeplay_core/src/database/schema.dart';
import 'package:skyeplay_core/src/metadata/metadata.dart';
import 'package:skyeplay_core/src/metadata/models/metadata.dart';
import 'package:skyeplay_core/src/services/discovery_service.dart';
import 'package:test/test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:hetu_script/hetu_script.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  group('DiscoveryService', () {
    late SkyeplayDatabase db;
    late MetadataPlugin metadataPlugin;
    late DiscoveryService discoveryService;

    setUp(() async {
      db = SkyeplayDatabase(NativeDatabase.memory());

      // Setup Mock MetadataPlugin
      final hetu = Hetu();
      hetu.init();
      final source = r'''
        class MockSearch {
           fun all(query) {
             return {
               "albums": [],
               "artists": [],
               "playlists": [],
               "tracks": [
                 {
                   "id": "related1",
                   "name": "Related Track 1",
                   "artists": [{"name": "Seed Artist", "id": "a1", "externalUri": ""}],
                   "album": {"name": "Album", "id": "al1", "externalUri": "", "artists": [], "albumType": "album", "images": []},
                   "durationMs": 300,
                   "externalUri": "",
                   "explicit": false,
                   "isrc": "US1"
                 },
                 {
                   "id": "related2",
                   "name": "Related Track 2",
                   "artists": [{"name": "Seed Artist", "id": "a1", "externalUri": ""}],
                   "album": {"name": "Album", "id": "al1", "externalUri": "", "artists": [], "albumType": "album", "images": []},
                   "durationMs": 300,
                   "externalUri": "",
                   "explicit": false,
                   "isrc": "US2"
                 }
               ]
             }
           }
        }

        class MockPlugin {
          var name = "Mock Plugin"
          var version = "1.0.0"
          
          var search = MockSearch()
          
          construct {}
        }
      ''';
      
      final bytes = hetu.compile(source, isModuleEntryScript: false, sourceName: 'plugin.ht');
      final config = PluginConfiguration(
        name: "Mock Plugin",
        description: "Test",
        version: "1.0.0",
        entryPoint: "MockPlugin",
        pluginApiVersion: "2.0.0",
        author: "Me"
      );
      
      metadataPlugin = await MetadataPlugin.create(YoutubeExplode(), config, bytes, enableModuleLoading: false);
      
      discoveryService = DiscoveryService(db, metadataPlugin);
    });

    tearDown(() async {
      await db.close();
    });

    test('Harvests related tracks', () async {
      // 1. Insert Seed Track
      final seedTrack = SpotubeFullTrackObject(
        id: "seed1",
        name: "Seed Track",
        externalUri: "",
        artists: [SpotubeSimpleArtistObject(name: "Seed Artist", id: "a1", externalUri: "")],
        album: SpotubeSimpleAlbumObject(name: "Album", id: "al1", externalUri: "", artists: [], albumType: SpotubeAlbumType.album),
        durationMs: 300,
        explicit: false,
        isrc: "SEED1"
      );
      
      await db.into(db.songs).insert(SongsCompanion.insert(
        id: "seed1",
        title: "Seed Track",
        artist: "Seed Artist",
        trackJson: jsonEncode(seedTrack.toJson()),
        createdAt: drift.Value(DateTime.now())
      ));

      // 2. Run Harvest
      await discoveryService.harvest("seed1");

      // 3. Verify Graph
      // Should have 3 songs (seed + 2 related)
      final songs = await db.select(db.songs).get();
      expect(songs.length, equals(3));
      
      final related1 = songs.firstWhere((s) => s.id == "related1");
      expect(related1.title, equals("Related Track 1"));
      
      // Should have 2 edges (seed -> related1, seed -> related2)
      final edges = await db.select(db.edges).get();
      expect(edges.length, equals(2));
      
      final edge1 = edges.firstWhere((e) => e.targetId == "related1");
      expect(edge1.sourceId, equals("seed1"));
      expect(edge1.weight, equals(1.0));
    });
  });
}
