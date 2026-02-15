import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Search result from YouTube — lightweight data class for UI
class YtSearchResult {
  final String videoId;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final Duration? duration;

  YtSearchResult({
    required this.videoId,
    required this.title,
    required this.artist,
    this.thumbnailUrl,
    this.duration,
  });

  String get durationLabel {
    if (duration == null) return '';
    final m = duration!.inMinutes;
    final s = duration!.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Direct youtube_explode_dart wrapper — anonymous, no API key, no auth.
class YouTubeSearchService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Search YouTube for videos matching [query].
  Future<List<YtSearchResult>> search(String query) async {
    final results = await _yt.search.search(query);
    return results
        .take(15)
        .map(
          (v) => YtSearchResult(
            videoId: v.id.value,
            title: v.title,
            artist: v.author,
            thumbnailUrl: v.thumbnails.mediumResUrl,
            duration: v.duration,
          ),
        )
        .toList();
  }

  /// Get the best audio-only stream info for a video.
  Future<({Stream<List<int>> stream, int size, String container, int bitrate})>
  getAudioStream(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final audioStreams = manifest.audioOnly.sortByBitrate();
    if (audioStreams.isEmpty) throw Exception('No audio streams found');
    final best = audioStreams.last;
    return (
      stream: _yt.videos.streamsClient.get(best),
      size: best.size.totalBytes,
      container: best.container.name,
      bitrate: best.bitrate.bitsPerSecond,
    );
  }

  /// Get total file size for progress tracking.
  Future<int> getStreamSize(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final audioStreams = manifest.audioOnly.sortByBitrate();
    if (audioStreams.isEmpty) return 0;
    return audioStreams.last.size.totalBytes;
  }

  void dispose() {
    _yt.close();
  }
}
