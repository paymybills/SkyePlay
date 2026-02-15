import 'package:flutter/material.dart';
import '../services/service_provider.dart';
import '../theme/matte_theme.dart';
import 'dart:ui';

class NowPlayingScreen extends StatelessWidget {
  final PlaybackState playback;
  const NowPlayingScreen({super.key, required this.playback});

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MatteColors.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: playback,
          builder: (context, _) {
            final elapsed = (playback.progress * playback.durationSeconds)
                .round();
            return Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: MatteColors.textSecondary,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Now Playing',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MatteColors.textTertiary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Album art
                Expanded(
                  child: Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: MatteColors.bgCard,
                        border: Border.all(
                          color: MatteColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          playback.currentThumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.album_rounded,
                            size: 80,
                            color: MatteColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Track info
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      Text(
                        playback.currentTitle ?? 'No track',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MatteColors.textPrimary,
                          decoration: TextDecoration.none,
                          fontFamily: 'Segoe UI',
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        playback.currentArtist ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: MatteColors.textTertiary,
                          decoration: TextDecoration.none,
                          fontFamily: 'Segoe UI',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Debug: ${playback.lastLog}\nNetwork: ${playback.bitrate}\nPos: ${_formatTime(playback.positionSeconds)} / ${_formatTime(playback.durationSeconds)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            color: MatteColors.textMuted,
                            fontFeatures: [FontFeature.tabularFigures()],
                            decoration: TextDecoration.none,
                            fontFamily: 'Consolas',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 4,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 10,
                          ),
                          trackHeight: 2,
                          activeTrackColor: MatteColors.textPrimary,
                          inactiveTrackColor: MatteColors.bgElevated,
                          thumbColor: MatteColors.textPrimary,
                        ),
                        child: Slider(
                          value: playback.progress.clamp(0.0, 1.0),
                          onChanged: playback.seekTo,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTime(elapsed),
                              style: const TextStyle(
                                fontSize: 10,
                                color: MatteColors.textMuted,
                                fontFeatures: [FontFeature.tabularFigures()],
                                decoration: TextDecoration.none,
                              ),
                            ),
                            Text(
                              _formatTime(playback.durationSeconds),
                              style: const TextStyle(
                                fontSize: 10,
                                color: MatteColors.textMuted,
                                fontFeatures: [FontFeature.tabularFigures()],
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 24, top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.shuffle_rounded,
                          size: 20,
                          color: MatteColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          size: 28,
                          color: MatteColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MatteColors.textPrimary,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withAlpha(25),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: playback.togglePlay,
                          icon: Icon(
                            playback.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 28,
                            color: MatteColors.bg,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          size: 28,
                          color: MatteColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.repeat_rounded,
                          size: 20,
                          color: MatteColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
