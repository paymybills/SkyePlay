import 'dart:io';
import 'package:skyeplay_core/src/metadata/metadata.dart';
import 'package:skyeplay_core/src/metadata/models/metadata.dart';
import 'package:test/test.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() {
  group('Skyeplay Core Harness', () {
    late MetadataPlugin metadataPlugin;

    setUpAll(() async {
      // Compile a mock plugin script
      final hetu = Hetu();
      hetu.init();
      final source = r'''
        class MockSearch {
          fun all(query) {
            return {
              "albums": [],
              "artists": [],
              "playlists": [],
              "tracks": []
            }
          }
        }

        class MockPlugin {
          var name = "Mock Plugin"
          var version = "1.0.0"
          var description = "A mock plugin for testing"
          var author = "Skyeplay"
          var homepage = "https://skyeplay.com"
          var repository = "https://github.com/skyeplay/core"
          var license = "MIT"
          
          var search = MockSearch()
          
          construct {}
        }
      ''';
      
      // Compile source to bytecode module "plugin"
      // We name it "plugin" because MetadataPlugin.create loads it as "plugin" module
      // hetu.compile doesn't embed module name in bytecode usually, loading does.
      final bytes = hetu.compile(source, isModuleEntryScript: false, sourceName: 'plugin.ht');
      
      final config = PluginConfiguration(
        name: "Mock Plugin",
        description: "A mock plugin for testing",
        version: "1.0.0",
        entryPoint: "MockPlugin", 
        pluginApiVersion: "2.0.0",
        author: "Skyeplay", // Added missing field
      );

      // Initialize the plugin with mock bytecode
      metadataPlugin = await MetadataPlugin.create(
        YoutubeExplode(),
        config,
        bytes,
      );
    });

    test("Initialize plugin", () async {
      print("Plugin initialized successfully!");
      expect(metadataPlugin, isNotNull);
    });

    test("Search query (Mock)", () async {
      try {
         final result = await metadataPlugin.search.all("Test");
         expect(result, isNotNull); 
         expect(result.tracks, isEmpty);
      } catch (e) {
         print("Search call failed: $e");
         rethrow;
      }
    });
  });
}
