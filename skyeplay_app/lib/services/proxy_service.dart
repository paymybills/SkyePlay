import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'stream_cache_service.dart';

/// A local HTTP proxy that serves audio from a growing local file managed by StreamCacheService.
/// This decouples the player from YouTube, preventing 403s and enabling robust seeking.
class AudioProxyService {
  final StreamCacheService _cacheService;
  HttpServer? _server;
  int _port = 0;

  AudioProxyService(this._cacheService);

  StreamCacheService get cacheService => _cacheService;

  int get port => _port;
  String get baseUrl => 'http://127.0.0.1:$_port';

  Future<void> start() async {
    if (_server != null) return;

    // Bind to loopback interface on an ephemeral port
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;

    debugPrint('🚀 Smart Cache Proxy running on $baseUrl');

    _server!.listen((HttpRequest request) async {
      try {
        if (request.uri.path == '/stream') {
          final id = request.uri.queryParameters['id'];
          if (id != null) {
            await _handleStreamRequest(request, id);
          } else {
            request.response.statusCode = HttpStatus.badRequest;
            request.response.close();
          }
        } else {
          request.response.statusCode = HttpStatus.notFound;
          request.response.close();
        }
      } catch (e) {
        debugPrint('❌ Proxy Error: $e');
        try {
          request.response.close();
        } catch (_) {}
      }
    });
  }

  Future<void> _handleStreamRequest(HttpRequest request, String videoId) async {
    RandomAccessFile? raf;
    try {
      debugPrint('🔗 Proxy Request: $videoId');
      // 1. Get Cache Status (starts download if needed)
      final status = await _cacheService.getCacheStatus(videoId);

      // Wait longer for initial data/metadata for long tracks
      int waitTries = 0;
      // We wait for at least 32KB of data or manifest success or completion
      while ((status.totalBytes == 0 || status.downloadedBytes < 32768) &&
          !status.isComplete &&
          waitTries < 100) {
        // Max 10s wait for initial buffer
        if (waitTries % 10 == 0) {
          debugPrint(
            '⏳ Proxy waiting for $videoId: ${status.downloadedBytes} bytes...',
          );
        }
        await Future.delayed(const Duration(milliseconds: 100));
        waitTries++;
        if (status.error != null) throw status.error!;
      }

      if (status.totalBytes == 0) {
        debugPrint('❌ Proxy Timeout waiting for metadata: $videoId');
        request.response.statusCode = HttpStatus.gatewayTimeout;
        request.response.close();
        return;
      }

      // 2. Parse Range
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      int start = 0;
      int end = status.totalBytes - 1; // Default to full file size (optimistic)

      if (rangeHeader != null) {
        final range = rangeHeader.replaceFirst('bytes=', '').split('-');
        start = int.tryParse(range[0]) ?? 0;
        if (range.length > 1 && range[1].isNotEmpty) {
          final requestedEnd = int.tryParse(range[1]);
          if (requestedEnd != null) end = requestedEnd;
        }
      }

      // 3. Safety Check: Do we have the start byte?
      if (start >= status.downloadedBytes) {
        // Wait a bit to see if download catches up
        int catchUpTries = 0;
        while (start >= status.downloadedBytes && catchUpTries < 20) {
          // Max 2s
          if (status.isComplete || status.error != null) break;
          await Future.delayed(const Duration(milliseconds: 100));
          catchUpTries++;
        }

        if (start >= status.downloadedBytes) {
          debugPrint(
            '⚠️ Range Not Satisfiable: Requested $start, have ${status.downloadedBytes}',
          );
          request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */${status.totalBytes}',
          );
          request.response.close();
          return;
        }
      }

      // 4. Cap end at what we have available?
      // Option A: Be strict. Only serve what we have. MPV will request next chunk.
      // Option B: Lie and say we have it all, but block? User said NO BLOCKING.
      // So Option A is safer.
      // Actually, standard HTTP: if we return 206, we specify Content-Range.
      // If we say `Content-Range: bytes START-END/TOTAL`, and send fewer bytes, it's a broken stream.
      // So we must cap the END to what we have downloaded (or slightly less to be safe).

      int safeEnd = status.downloadedBytes - 1;
      if (end > safeEnd) end = safeEnd;
      if (end < start)
        end = start; // Should not happen if start < downloadedBytes

      final contentLength = end - start + 1;

      // 5. Serve Content
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.contentType = ContentType(
        'audio',
        'mp4',
      ); // Assuming container or detect?
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/${status.totalBytes}',
      );
      request.response.headers.contentLength = contentLength;
      request.response.headers.add('Accept-Ranges', 'bytes');

      try {
        raf = await status.file.open(mode: FileMode.read);
        await raf.setPosition(start);
      } catch (e) {
        debugPrint('❌ Proxy failed to open file: $e');
        rethrow;
      }

      // Serve in chunks to allow efficient piping without loading all into RAM
      const chunkSize = 64 * 1024;
      int bytesToSend = contentLength;

      while (bytesToSend > 0) {
        int toRead = (bytesToSend > chunkSize) ? chunkSize : bytesToSend;
        final data = await raf.read(toRead);
        if (data.isEmpty) break; // EOF unexpected (file truncated?)
        request.response.add(data);
        bytesToSend -= data.length;
        // await request.response.flush(); // Optional
      }

      await request.response.close();
      // debugPrint('✅ Served Range: $start-$end / ${status.totalBytes}');
    } catch (e) {
      if (!e.toString().contains('Connection closed')) {
        debugPrint('❌ Proxy Error: $e');
      }
      try {
        request.response.close();
      } catch (_) {}
    } finally {
      try {
        await raf?.close();
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }
}
