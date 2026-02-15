import 'dart:convert';
import 'dart:io';
import 'package:skyeplay_core/src/database/database.dart';
import 'package:skyeplay_core/src/database/schema.dart';
import 'package:skyeplay_core/src/metadata/metadata.dart';
import 'package:skyeplay_core/src/metadata/models/metadata.dart';
import 'package:skyeplay_core/src/services/discovery_service.dart';
import 'package:skyeplay_core/src/services/download_manager.dart';
import 'package:skyeplay_core/src/services/recommender_engine.dart';
import 'package:skyeplay_core/src/services/sync_manager.dart';
import 'package:test/test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:hetu_script/hetu_script.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  group('SyncManager Integration', () {
    late SkyeplayDatabase db;
    late MetadataPlugin metadataPlugin;
    late DiscoveryService discoveryService;
    late DownloadManager downloadManager;
    late RecommenderEngine recommender;
    late SyncManager syncManager;
    late Directory tempDir;

    setUp(() async {
      db = SkyeplayDatabase(NativeDatabase.memory());
      tempDir = await Directory.systemTemp.createTemp('skyeplay_sync_test');
      
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
                   "id": "rec1",
                   "name": "Recommended Track 1",
                   "artists": [{"name": "Seed Artist", "id": "a1", "externalUri": ""}],
                   "album": {"name": "Album", "id": "al1", "externalUri": "", "artists": [], "albumType": "album", "images": []},
                   "durationMs": 300,
                   "externalUri": "",
                   "explicit": false,
                   "isrc": "REC1"
                 }
               ]
             }
           }
        }
        
        class MockAudioSource {
           fun matches(track) {
             return [{
               "id": "match1", 
               "title": "Match title", 
               "artists": ["Author"], 
               "duration": 300000, 
               "externalUri": "http://mock",
               "thumbnail": "http://thumb"
             }]
           }
           fun streams(match) {
             return [{
               "url": "http://mock.url/audio.mp3", 
               "type": "lossy", 
               "bitrate": 128000, 
               "container": "mp3", 
               "videoId": "v1", 
               "codec": "mp3", 
               "size": 1024
             }]
           }
        }

        class MockPlugin {
          var name = "Mock Plugin"
          var version = "1.0.0"
          var search = MockSearch()
          var audioSource = MockAudioSource()
          
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
      downloadManager = DownloadManager(db, metadataPlugin, tempDir.path);
      recommender = RecommenderEngine(db);
      syncManager = SyncManager(db, downloadManager, discoveryService, recommender);
      
      await downloadManager.init();
      
      // Seed the Songs table so `recommender.randomTrack` finds something if queue is empty
      // Or rely on fallback logic if db is empty?
      // Recommender random fallback queries `songs`. If empty, returns null.
      // So we MUST seed at least one song.
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
        id: seedTrack.id,
        title: seedTrack.name,
        artist: "Seed Artist",
        trackJson: jsonEncode(seedTrack.toJson()),
        createdAt: drift.Value(DateTime.now())
      ));
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    test('Triggers download when queue is low', () async {
      // 1. Initial State: Queue Empty (0 downloads)
      var downloads = await db.select(db.downloads).get();
      expect(downloads.length, equals(0));
      
      // 2. Run checkQueue
      await syncManager.checkQueue();
      
      // 3. Verify: Download should be queued
      // Recommender should pick seed1 (via random or loop) or something else?
      // Wait, Recommender default is random if no current track.
      // Random will pick seed1.
      // Then DownloadManager queues seed1.
      // But seed1 is already in Songs.
      // DownloadManager only checks `downloads` table.
      
      downloads = await db.select(db.downloads).get();
      expect(downloads.length, equals(1));
      expect(downloads.first.id, equals("seed1")); // Because random fallback picked the only song
      
      // Status should be pending (0) or downloading (1) or done (2/3) depending on how fast `_processQueue` ran.
      // `queueDownload` calls `_processQueue` without waiting.
      // `checkQueue` awaits `queueDownload`.
      
      // Let's give it a moment for the async mock download to 'finish' (it's instant file creation)
      await Future.delayed(Duration(milliseconds: 100));
      
      final download = await (db.select(db.downloads)..where((t) => t.id.equals("seed1"))).getSingle();
      expect(download.status, isIn([1, 2])); // Downloading or Done
      
      // 4. Verify Side Effect: Harvest
      // `checkQueue` calls `harvest` AFTER `queueDownload`.
      // It awaits `queueDownload`, but `queueDownload` returns early (after insert)?
      // No, `queueDownload` calls `_processQueue` at end. `_processQueue` is async.
      // `queueDownload` returns void Future.
      
      // `checkQueue` takes `nextTrack` which is `seed1`.
      // It calls `harvest("seed1")`.
      // Harvest should find "rec1" (from Mock search).
      // So Songs table should have "rec1".
      
      final songs = await db.select(db.songs).get();
      // Should contain seed1 AND rec1
      expect(songs.map((s) => s.id), contains("rec1"));
    });
    
    test('Does not trigger when queue is full', () async {
      // Fill queue with 5 items
      for (int i=0; i<5; i++) {
        await db.into(db.downloads).insert(DownloadsCompanion.insert(
          id: "d$i",
          trackJson: "{}",
          status: const drift.Value(0), // Pending
          createdAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ));
      }
      
      await syncManager.checkQueue();
      
      // Should still be 5
      final downloads = await db.select(db.downloads).get();
      expect(downloads.length, equals(5));
    });
  });
}
