import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'youtube_search_service.dart';
import 'service_provider.dart';

/// Downloads audio files from YouTube using youtube_explode_dart.
/// Tracks progress and updates MusicStore in real time.
class DownloadService {
  final YouTubeSearchService _yt;
  final MusicStore _store;
  final String downloadDir;
  bool _isProcessing = false;

  DownloadService(this._yt, this._store, {required this.downloadDir}) {
    Directory(downloadDir).createSync(recursive: true);
  }

  /// Queue a download from a search result.
  Future<void> queue(YtSearchResult result) async {
    // Add to store immediately as pending
    _store.addSong(
      SongData(
        id: result.videoId,
        title: result.title,
        artist: result.artist,
        thumbnailUrl: result.thumbnailUrl,
      ),
    );
    _store.addDownload(
      DownloadData(
        id: result.videoId,
        title: result.title,
        artist: result.artist,
        status: 0, // pending
      ),
    );

    // Process queue
    _processNext();
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;

    final pending = _store.downloads.where((d) => d.status == 0).toList();
    if (pending.isEmpty) return;

    _isProcessing = true;
    final dl = pending.first;

    try {
      // Mark as downloading
      _store.addDownload(
        DownloadData(
          id: dl.id,
          title: dl.title,
          artist: dl.artist,
          status: 1,
          progress: 0.0,
        ),
      );

      // Use consolidated getAudioStream
      final audioInfo = await _yt.getAudioStream(dl.id);
      final totalSize = audioInfo.size;
      final stream = audioInfo.stream;

      // Determine filename and path
      final safeTitle = dl.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final filePath = '$downloadDir/$safeTitle.${audioInfo.container}';
      final file = File(filePath);
      final sink = file.openWrite();

      int received = 0;
      int lastNotify = 0;

      await for (final List<int> chunk in stream) {
        sink.add(chunk);
        received += chunk.length;

        // Update progress every ~50KB to avoid spamming UI
        if (received - lastNotify > 50000 || received >= totalSize) {
          lastNotify = received;
          final progress = totalSize > 0 ? received / totalSize : 0.0;
          _store.addDownload(
            DownloadData(
              id: dl.id,
              title: dl.title,
              artist: dl.artist,
              status: 1,
              progress: progress.clamp(0.0, 1.0),
              filePath: filePath,
            ),
          );
        }
      }

      await sink.flush();
      await sink.close();

      // Mark complete
      _store.addDownload(
        DownloadData(
          id: dl.id,
          title: dl.title,
          artist: dl.artist,
          status: 2,
          progress: 1.0,
          filePath: filePath,
        ),
      );

      // Update song with file path
      _store.updateSongFilePath(dl.id, filePath);

      debugPrint(
        '✅ Downloaded: ${dl.title} → $filePath (${(received / 1024 / 1024).toStringAsFixed(1)} MB)',
      );
    } catch (e) {
      debugPrint('❌ Download failed: ${dl.title} — $e');
      _store.addDownload(
        DownloadData(
          id: dl.id,
          title: dl.title,
          artist: dl.artist,
          status: 3, // failed
        ),
      );
    } finally {
      _isProcessing = false;
      // Process next in queue
      _processNext();
    }
  }
}
