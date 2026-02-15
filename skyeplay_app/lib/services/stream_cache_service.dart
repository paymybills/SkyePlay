import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'youtube_search_service.dart';

/// Tracks the state of a cached stream
class CacheStatus {
  final String videoId;
  final File file;
  int totalBytes;
  int downloadedBytes;
  bool isComplete;
  DateTime lastAccess;
  Object? error;

  CacheStatus({
    required this.videoId,
    required this.file,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.isComplete = false,
  }) : lastAccess = DateTime.now();
}

/// Manages background downloads of audio streams to local temp files.
/// This acts as a "Download Manager" for the Proxy to read from.
class StreamCacheService {
  final YouTubeSearchService _yt;
  final Map<String, CacheStatus> _activeCaches = {};

  // Keep caches for a while, but eventually clean them up
  static const Duration _cacheRetention = Duration(minutes: 60);

  StreamCacheService(this._yt);

  /// Get the current status of a stream. Starts download if not active.
  Future<CacheStatus> getCacheStatus(String videoId) async {
    if (_activeCaches.containsKey(videoId)) {
      final status = _activeCaches[videoId]!;
      status.lastAccess = DateTime.now();
      return status;
    }
    return await _startDownload(videoId);
  }

  /// Wait for metadata (totalBytes) to be populated for a stream.
  Future<void> waitForMetadata(String videoId) async {
    final status = await getCacheStatus(videoId);
    int waitTries = 0;
    while (status.totalBytes == 0 && status.error == null && waitTries < 100) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitTries++;
    }
    if (status.error != null) throw status.error!;
    if (status.totalBytes == 0)
      throw TimeoutException('Timeout waiting for metadata');
  }

  Future<CacheStatus> _startDownload(String videoId) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/cache_$videoId.m4a');

    // Check if file already exists and is valid (simple check)
    if (await file.exists()) {
      // Ideally we'd valid size, but for now let's assume if it's there from a previous run
      // we might want to overwrite or resume. Let's overwrite to be safe with signatures.
      // Actually, to support "Smart Cache", ideally we keeps it.
      // For this MVP, let's truncate to ensure fresh robust link.
      await file.delete();
    }

    final status = CacheStatus(videoId: videoId, file: file);
    _activeCaches[videoId] = status;

    // Run in background - do NOT await this
    _performDownload(videoId, status, file);

    return status;
  }

  Future<void> _performDownload(
    String videoId,
    CacheStatus status,
    File file,
  ) async {
    final sink = file.openWrite();
    try {
      debugPrint('📥 Cache Start: $videoId -> ${file.path}');

      // Get best stream and metadata in one call
      debugPrint('🌐 Fetching manifest for: $videoId');
      final streamInfo = await _yt.getAudioStream(videoId);
      status.totalBytes = streamInfo.size;
      debugPrint('📄 Manifest received: $videoId (${streamInfo.size} bytes)');

      final stream = streamInfo.stream;

      await for (final chunk in stream) {
        sink.add(chunk);
        status.downloadedBytes += chunk.length;
        if (status.downloadedBytes < 300000 &&
            status.downloadedBytes % 100000 == 0) {
          debugPrint(
            '⏳ Buffering $videoId: ${status.downloadedBytes}/${status.totalBytes}',
          );
        }
      }

      await sink.flush();
      status.isComplete = true;
      debugPrint(
        '✅ Cache Complete: $videoId (${status.downloadedBytes} bytes)',
      );
    } catch (e) {
      debugPrint('❌ Cache Error: $videoId - $e');
      status.error = e;
      _activeCaches.remove(videoId);
    } finally {
      await sink.close();
    }
  }

  /// Prune old caches
  void cleanup() {
    final now = DateTime.now();
    _activeCaches.removeWhere((id, status) {
      if (now.difference(status.lastAccess) > _cacheRetention) {
        try {
          status.file.delete();
        } catch (_) {}
        return true;
      }
      return false;
    });
  }
}
