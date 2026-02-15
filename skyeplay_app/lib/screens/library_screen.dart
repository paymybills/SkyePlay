import 'package:flutter/material.dart';
import 'package:skyeplay_core/skyeplay_core.dart';
import '../services/service_provider.dart';
import '../theme/matte_theme.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  Future<void> _playSong(
    BuildContext context,
    Song song,
    PlaybackState playback,
  ) async {
    // 1. Play using local path if available, otherwise proxy
    playback.play(
      id: song.id,
      title: song.title,
      artist: song.artist,
      localPath: song.filePath,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sp = ServiceProvider.of(context);
    final store = sp.store;
    final playback = sp.playback;

    return Container(
      color: MatteColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Library',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: MatteColors.textPrimary,
                    ),
                  ),
                  _Chip(
                    label: '${store.songs.length} songs',
                    color: MatteColors.accent,
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([store, playback]),
              builder: (context, _) {
                final songs = store.songs;
                if (songs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.library_music_rounded,
                          size: 40,
                          color: MatteColors.borderSubtle,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No songs yet',
                          style: TextStyle(
                            color: MatteColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final isPlaying = song.id == playback.currentId;
                    final hasFile = song.filePath != null;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _playSong(context, song, playback),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: isPlaying
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: MatteColors.activeHighlight,
                                )
                              : null,
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: isPlaying
                                      ? MatteColors.bgElevated
                                      : MatteColors.bgCard,
                                  border: Border.all(
                                    color: MatteColors.borderSubtle,
                                    width: 0.5,
                                  ),
                                ),
                                child: Icon(
                                  isPlaying
                                      ? Icons.equalizer_rounded
                                      : Icons.music_note_rounded,
                                  size: 18,
                                  color: isPlaying
                                      ? MatteColors.accent
                                      : MatteColors.textMuted,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isPlaying
                                            ? MatteColors.accent
                                            : MatteColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      song.artist,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: MatteColors.textTertiary,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                              if (hasFile)
                                Icon(
                                  Icons.offline_pin_rounded,
                                  size: 12,
                                  color: MatteColors.success.withAlpha(180),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withAlpha(40), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
