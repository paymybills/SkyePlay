import 'dart:io';
import 'dart:convert';
import 'package:skyeplay_core/src/database/database.dart';
import 'package:skyeplay_core/src/metadata/metadata.dart';
import 'package:skyeplay_core/src/metadata/models/metadata.dart';
import 'package:skyeplay_core/src/services/download_manager.dart';
import 'package:test/test.dart';
import 'package:drift/native.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  group('DownloadManager', () {
    late SkyeplayDatabase db;
    late MetadataPlugin metadataPlugin;
    late DownloadManager downloadManager;
    late Directory tempDir;

    setUp(() async {
      db = SkyeplayDatabase(NativeDatabase.memory());
      tempDir = await Directory.systemTemp.createTemp('skyeplay_test');

      // Setup Mock MetadataPlugin
      final hetu = Hetu();
      hetu.init();
      final source = r'''
        class MockAudioSource {
          fun matches(track) {
            return [
              {
                "id": "video1",
                "title": track["name"],
                "artists": ["artist1"],
                "duration": 300000,
                "externalUri": "http://example.com"
              }
            ]
          }
          fun streams(match) {
             return [
               {
                 "url": "http://example.com/stream.mp4",
                 "container": "mp4",
                 "type": "lossy",
                 "bitrate": 128000.0,
                 "codec": "aac"
               }
             ]
          }
        }

        class MockPlugin {
          var name = "Mock Plugin"
          var version = "1.0.0"
          
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
      
      metadataPlugin = await MetadataPlugin.create(YoutubeExplode(), config, bytes);
      
      downloadManager = DownloadManager(db, metadataPlugin, tempDir.path);
      await downloadManager.init();
    });

    tearDown(() async {
      await db.close();
      await tempDir.delete(recursive: true);
    });

    test('Queue and download track', () async {
      final track = SpotubeFullTrackObject(
        id: "track1",
        name: "Test Track",
        externalUri: "http://spotify.com/track/1",
        artists: [SpotubeSimpleArtistObject(name: "Test Artist", id: "artist1", externalUri: "")],
        album: SpotubeSimpleAlbumObject(
           name: "Test Album", 
           id: "album1", 
           externalUri: "", 
           artists: [], 
           albumType: SpotubeAlbumType.album,
           images: [SpotubeImageObject(url: "http://art.com", width: 100, height: 100)]
        ),
        durationMs: 300,
        explicit: false,
        isrc: "US123456789",
      );

      await downloadManager.queueDownload(track);

      // Wait a bit for async process
      await Future.delayed(Duration(seconds: 1));

      // Check DB
      final download = await (db.select(db.downloads)..where((t) => t.id.equals("track1"))).getSingle();
      
      print("Download status: ${download.status}");
      
      // Status should be 2 (Completed) or at least 1 (Downloading)
      // Since we mocked http download with file creation, it should be fast.
      expect(download.status, equals(2));
      expect(download.filePath, isNotNull);
      expect(await File(download.filePath!).exists(), isTrue);
    });

    test('Cancel download', () async {
      final track = SpotubeFullTrackObject(
        id: "track2",
        name: "Test Track 2",
        externalUri: "http://spotify.com/track/2",
        artists: [SpotubeSimpleArtistObject(name: "Test Artist 2", id: "artist2", externalUri: "")],
        album: SpotubeSimpleAlbumObject(
           name: "Test Album 2", 
           id: "album2", 
           externalUri: "", 
           artists: [], 
           albumType: SpotubeAlbumType.album,
           images: [SpotubeImageObject(url: "http://art.com", width: 100, height: 100)]
        ),
        durationMs: 300,
        explicit: false,
        isrc: "US123456789",
      );

      // Queue and immediately cancel? 
      // Or mock a slow download?
      // Since mock is fast, it will likely complete before we cancel.
      // But we can check if file is deleted.
      
      await downloadManager.queueDownload(track);
      await Future.delayed(Duration(milliseconds: 500)); // Let it start/finish
      
      await downloadManager.cancelDownload("track2");
      
      // Check DB - should be gone
      final download = await (db.select(db.downloads)..where((t) => t.id.equals("track2"))).getSingleOrNull();
      expect(download, isNull);
      
      // File should be deleted (if we could predict path)
      // We can't easily predict path here unless we know exact string structure.
      // But in this test environment, we know it's tempDir/Artist - Track.container
    });
  });
}

// Add memory constructor to database.dart if needed, or use override
// extension on SkyeplayDatabase {
//   static SkyeplayDatabase memory() {
//      return SkyeplayDatabase(NativeDatabase.memory());
//   }
// }
