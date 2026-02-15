import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';

import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_std/hetu_std.dart';
import 'package:hetu_otp_util/hetu_otp_util.dart';
// import 'package:hetu_spotube_plugin/hetu_spotube_plugin.dart';

// ... (omitted)

    // Load bindings
    HetuStdLoader.loadBindings(hetu);
    /*
    HetuSpotubePluginLoader.loadBindings(
      hetu,
      localStorageImpl: DummyLocalStorage(),
      onNavigatorPush: (route) async {},
      onNavigatorPop: () async {},
      onShowForm: (title, fields) async => null,
      createYoutubeEngine: () => YouTubeEngine(
        search: (query) async {
             // Adapt youtube_explode results to Map
             final results = await youtubeEngine.search.search(query);
             return results.map((v) => {
               'id': v.id.value,
               'title': v.title,
               'author': v.author,
               'duration': v.duration?.inSeconds,
               'thumbnails': {
                  'low': v.thumbnails.lowResUrl,
                  'medium': v.thumbnails.mediumResUrl,
                  'high': v.thumbnails.highResUrl,
               }
             }).toList();
        },
        getVideo: (videoId) async {
             var v = await youtubeEngine.videos.get(videoId);
             return {
               'id': v.id.value,
               'title': v.title,
               'author': v.author,
               'duration': v.duration?.inSeconds,
               'isLive': v.isLive,
               'thumbnails': {
                  'low': v.thumbnails.lowResUrl,
                  'medium': v.thumbnails.mediumResUrl,
                  'high': v.thumbnails.highResUrl,
               }
             };
        },
        streamManifest: (videoId) async {
             var manifest = await youtubeEngine.videos.streamsClient.getManifest(videoId);
             // Return audio streams
             return manifest.audioOnly.map((s) => {
               'url': s.url.toString(),
               'quality': s.qualityLabel,
               'bitrate': s.bitrate.bitsPerSecond,
               'container': s.container.name,
               'videoId': s.videoId,
               'codec': s.codec.subtype,
               'size': s.size.totalBytes,
             }).toList();
        },
      ),
    );
    */

    // Load bytecode modules
    if (enableModuleLoading) {
      try {
        final stdUri = await Isolate.resolvePackageUri(Uri.parse('package:hetu_std/'));
      if (stdUri != null) {
        // package:hetu_std/ resolves to lib/, so parent is package root
        final packagePath = File(stdUri.toFilePath()).parent.path;
        await HetuStdLoader.loadBytecodePureDart(hetu, packagePath);
      }

      final otpUri = await Isolate.resolvePackageUri(Uri.parse('package:hetu_otp_util/'));
      if (otpUri != null) {
        final packagePath = File(otpUri.toFilePath()).parent.path;
        await HetuOtpUtilLoader.loadBytecodePureDart(hetu, packagePath);
      }

      /*
      final spotubePluginUri = await Isolate.resolvePackageUri(Uri.parse('package:hetu_spotube_plugin/'));
      if (spotubePluginUri != null) {
        final packagePath = File(spotubePluginUri.toFilePath()).parent.path;
        final byteCodePath = join(packagePath, 'lib', 'assets', 'bytecode', 'spotube_plugin.out');
        final byteCodeFile = File(byteCodePath);
        print('Loading spotube_plugin bytecode from: $byteCodePath (exists: ${await byteCodeFile.exists()})');
        if (await byteCodeFile.exists()) {
             final bytes = await byteCodeFile.readAsBytes();
             hetu.loadBytecode(bytes: bytes, moduleName: 'spotube_plugin');
        } else {
             print('Warning: spotube_plugin bytecode not found!');
        }
      } else {
        print('Warning: package:hetu_spotube_plugin/ not resolved');
      }
      */
      } catch (e, stack) {
        print('Error loading modules: $e\n$stack');
      }
    }

    hetu.loadBytecode(bytes: byteCode, moduleName: "plugin");

    hetu.eval("""
      import "module:plugin" as plugin
      
      var Plugin = plugin.${config.entryPoint}
      
      var metadataPlugin

      fun pluginEntryPoint(config) {
        metadataPlugin = Plugin()
        return metadataPlugin
      }
    """);

    final instance = hetu.invoke(
      "pluginEntryPoint",
      positionalArgs: [config.toJson()],
    );

    return MetadataPlugin._(hetu);
  }

  final Hetu hetu;

  late final MetadataAuthEndpoint auth;
  late final MetadataPluginAudioSourceEndpoint audioSource;
  late final MetadataPluginAlbumEndpoint album;
  late final MetadataPluginArtistEndpoint artist;
  late final MetadataPluginBrowseEndpoint browse;
  late final MetadataPluginSearchEndpoint search;
  late final MetadataPluginPlaylistEndpoint playlist;
  late final MetadataPluginTrackEndpoint track;
  late final MetadataPluginUserEndpoint user;
  late final MetadataPluginCore core;

  MetadataPlugin._(this.hetu) {
    auth = MetadataAuthEndpoint(hetu);
    audioSource = MetadataPluginAudioSourceEndpoint(hetu);
    artist = MetadataPluginArtistEndpoint(hetu);
    album = MetadataPluginAlbumEndpoint(hetu);
    browse = MetadataPluginBrowseEndpoint(hetu);
    search = MetadataPluginSearchEndpoint(hetu);
    playlist = MetadataPluginPlaylistEndpoint(hetu);
    track = MetadataPluginTrackEndpoint(hetu);
    user = MetadataPluginUserEndpoint(hetu);
    core = MetadataPluginCore(hetu);
  }
}
