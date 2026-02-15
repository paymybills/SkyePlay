import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:skyeplay_core/skyeplay_core.dart'; // Models (Song, SkyeplayDatabase)

import 'youtube_search_service.dart';
import 'download_service.dart';
import 'proxy_service.dart';
import 'stream_cache_service.dart';

// The "Service Locator" for the app.
class ServiceProvider extends InheritedWidget {
  final SkyeplayDatabase db;
  final DownloadService downloadService;
  final YouTubeSearchService ytSearch;
  final PlaybackState playback;
  final MusicStore store;
  final StreamCacheService streamCache;
  final AudioProxyService proxyService;

  const ServiceProvider({
    Key? key,
    required this.db,
    required this.downloadService,
    required this.ytSearch,
    required this.playback,
    required this.store,
    required this.streamCache,
    required this.proxyService,
    required Widget child,
  }) : super(key: key, child: child);

  static ServiceProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ServiceProvider>()!;
  }

  @override
  bool updateShouldNotify(ServiceProvider oldWidget) => false;
}

// Global initialization function
class Services {
  late final SkyeplayDatabase _db;
  late final DownloadService _downloadService;
  late final YouTubeSearchService _ytSearch;
  late final StreamCacheService _streamCache;
  late final AudioProxyService _proxyService;
  late final PlaybackState _playback;
  late final MusicStore _store;

  Future<void> initialize() async {
    // 1. Initialize Database
    final appDocDir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(appDocDir.path, 'skyeplay.db'));
    _db = SkyeplayDatabase(NativeDatabase(dbFile));

    // 2. Core Services
    _ytSearch = YouTubeSearchService();
    _streamCache = StreamCacheService(_ytSearch);
    _proxyService = AudioProxyService(_streamCache);
    await _proxyService.start();

    // 3. State Management
    _store = MusicStore(_db);
    _downloadService = DownloadService(
      _ytSearch,
      _store,
      downloadDir: p.join(appDocDir.path, 'Skyeplay/Music'),
    );
    _playback = PlaybackState(_proxyService);

    await _store.loadLibrary();
  }

  SkyeplayDatabase get db => _db;
  DownloadService get downloadService => _downloadService;
  YouTubeSearchService get ytSearch => _ytSearch;
  PlaybackState get playback => _playback;
  MusicStore get store => _store;
  StreamCacheService get streamCache => _streamCache;
  AudioProxyService get proxyService => _proxyService;
}

// --- App State Management ---

class PlaybackState extends ChangeNotifier {
  final Player _player = Player();
  late final VideoController _controller;
  final AudioProxyService _proxy;

  // State
  String? currentId;
  String? currentTitle;
  String? currentArtist;
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  String lastLog = "";

  PlaybackState(this._proxy) {
    _controller = VideoController(_player);

    _player.stream.playing.listen((state) {
      isPlaying = state;
      notifyListeners();
    });

    _player.stream.position.listen((pos) {
      position = pos;
      notifyListeners();
    });

    _player.stream.duration.listen((dur) {
      duration = dur;
      notifyListeners();
    });

    _player.stream.error.listen((error) {
      debugPrint("MPV Error: $error");
      lastLog = "Error: $error";
      notifyListeners();
    });
  }

  VideoController get controller => _controller;

  // Helpers for UI
  double get progress => duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds
      : 0.0;

  int get positionSeconds => position.inSeconds;
  int get durationSeconds => duration.inSeconds;

  bool get hasTrack => currentId != null;

  String get currentThumbnailUrl => "https://via.placeholder.com/150";
  String get bitrate => "Smart Cache";

  Future<void> togglePlay() async {
    if (isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seekTo(double progress) async {
    final dropped = (progress * duration.inMilliseconds).toInt();
    await seek(Duration(milliseconds: dropped));
  }

  Future<void> play({
    required String id,
    required String title,
    String? artist,
    String? localPath,
  }) async {
    currentId = id;
    currentTitle = title;
    currentArtist = artist ?? "Unknown";
    notifyListeners();

    try {
      Media source;
      if (localPath != null) {
        source = Media(localPath);
        lastLog = "Local playback";
      } else {
        lastLog = "Fetching metadata...";
        notifyListeners();

        // Pre-warm the cache by ensuring metadata is fetched BEFORE MPV hits the proxy
        // This prevents MPV from timing out while the proxy is waiting for manifest.
        try {
          await _proxy.cacheService.waitForMetadata(id);
        } catch (e) {
          debugPrint("Pre-warm error: $e");
          lastLog = "Metadata error: $e";
          notifyListeners();
          // We can still try to proceed, MPV might handle it better now that we tried
        }

        final proxyUrl = '${_proxy.baseUrl}/stream?id=$id';
        lastLog = "Buffering...";
        source = Media(proxyUrl);
      }

      await _player.open(source);
      await _player.play();
    } catch (e) {
      lastLog = "Error: $e";
      notifyListeners();
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }
}

// Compatibility classes for DownloadService
class SongData {
  final String id;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final String? filePath;

  SongData({
    required this.id,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.filePath,
  });
}

class DownloadData {
  final String id;
  final String title;
  final String artist;
  final int status; // 0=pending, 1=downloading, 2=done, 3=failed
  final double progress;
  final String? filePath;

  DownloadData({
    required this.id,
    required this.title,
    required this.artist,
    required this.status,
    this.progress = 0.0,
    this.filePath,
  });
}

class MusicStore extends ChangeNotifier {
  final SkyeplayDatabase _db;
  final List<DownloadData> _downloads = [];
  List<Song> songs = [];
  bool isLoading = true;

  MusicStore(this._db);

  List<DownloadData> get downloads => _downloads;

  void addDownload(DownloadData data) {
    final index = _downloads.indexWhere((d) => d.id == data.id);
    if (index != -1) {
      _downloads[index] = data;
    } else {
      _downloads.add(data);
    }
    notifyListeners();
  }

  void addSong(SongData data) {
    // Placeholder logic - should add to DB
    _db
        .into(_db.songs)
        .insertOnConflictUpdate(
          SongsCompanion.insert(
            id: data.id,
            title: data.title,
            artist: data.artist,
            trackJson: '{}', // Placeholder
            filePath: Value(data.filePath),
          ),
        );
    loadLibrary();
  }

  void updateSongFilePath(String id, String path) {
    _db.update(_db.songs)
      ..where((t) => t.id.equals(id))
      ..write(SongsCompanion(filePath: Value(path)));
    loadLibrary();
  }

  Future<void> loadLibrary() async {
    isLoading = true;
    notifyListeners();
    try {
      songs = await _db.select(_db.songs).get();
    } catch (e) {
      debugPrint("Store Error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
