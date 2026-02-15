import 'package:flutter/material.dart';
import '../services/service_provider.dart';
import '../services/youtube_search_service.dart';
import '../services/download_service.dart';
import '../theme/matte_theme.dart';
import '../main.dart' show ytService, dlService;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  bool _isSearching = false;
  String? _error;
  List<YtSearchResult> _results = [];

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _error = null;
    });
    try {
      final results = await ytService.search(query);
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Search failed: $e';
        _isSearching = false;
      });
    }
  }

  void _queueDownload(YtSearchResult result) {
    dlService.queue(result);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⬇ Queued: ${result.title}',
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: MatteColors.bgElevated,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _playResult(YtSearchResult r, PlaybackState playback) async {
    // Optimistically show now playing
    playback.play(id: r.videoId, title: r.title, artist: r.artist);

    try {
      await ytService.getAudioStream(r.videoId);
      if (mounted) {
        playback.play(id: r.videoId, title: r.title, artist: r.artist);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Playback failed: $e')));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ServiceProvider.of(context).playback;

    return Container(
      color: MatteColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Search',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MatteColors.textPrimary,
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: MatteColors.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MatteColors.border, width: 0.5),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: MatteColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MatteColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Songs, artists, albums...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: MatteColors.textMuted,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _search,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 3),
                    child: TextButton(
                      onPressed: () => _search(_controller.text),
                      style: TextButton.styleFrom(
                        backgroundColor: MatteColors.bgElevated,
                        foregroundColor: MatteColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                          side: const BorderSide(
                            color: MatteColors.border,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Go',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: MatteColors.textTertiary,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Searching YouTube...',
                          style: TextStyle(
                            color: MatteColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: MatteColors.error,
                        fontSize: 11,
                      ),
                    ),
                  )
                : _results.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 40,
                          color: MatteColors.borderSubtle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Search for music to begin',
                          style: TextStyle(
                            color: MatteColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Powered by youtube_explode (anonymous)',
                          style: TextStyle(
                            color: MatteColors.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final r = _results[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _playResult(r, playback),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: MatteColors.bgCard,
                                    border: Border.all(
                                      color: MatteColors.borderSubtle,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: r.thumbnailUrl != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                          child: Image.network(
                                            r.thumbnailUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.album_rounded,
                                                  size: 20,
                                                  color: MatteColors.textMuted,
                                                ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.album_rounded,
                                          size: 20,
                                          color: MatteColors.textMuted,
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.title,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: MatteColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        r.artist,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: MatteColors.textTertiary,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  r.durationLabel,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: MatteColors.textMuted,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => _queueDownload(r),
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    size: 16,
                                    color: MatteColors.accent,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
