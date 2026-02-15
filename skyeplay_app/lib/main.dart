import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:skyeplay_core/skyeplay_core.dart';
import 'package:drift/native.dart';

import 'theme/matte_theme.dart';
import 'services/service_provider.dart';
import 'services/youtube_search_service.dart';
import 'services/proxy_service.dart';
import 'services/download_service.dart';
import 'services/stream_cache_service.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/now_playing_screen.dart';

// Global service references (optional legacy access)
late final YouTubeSearchService ytService;
late final DownloadService dlService;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // 1. Initialize DB
  final appDocDir = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(appDocDir.path, 'skyeplay.db'));
  final db = SkyeplayDatabase(NativeDatabase(dbFile));

  // 2. Initialize Core Services
  ytService = YouTubeSearchService();
  final streamCache = StreamCacheService(ytService);
  final proxy = AudioProxyService(streamCache);
  await proxy.start();

  // 3. Initialize State
  final store = MusicStore(db);
  dlService = DownloadService(
    ytService,
    store,
    downloadDir: p.join(appDocDir.path, 'Skyeplay/Music'),
  );
  final playback = PlaybackState(proxy);

  await store.loadLibrary();

  runApp(
    ServiceProvider(
      db: db,
      downloadService: dlService,
      ytSearch: ytService,
      playback: playback,
      store: store,
      streamCache: streamCache,
      proxyService: proxy,
      child: const SkyePlayApp(),
    ),
  );
}

class SkyePlayApp extends StatelessWidget {
  const SkyePlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkyePlay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: MatteColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: MatteColors.accent,
          secondary: MatteColors.accentWarm,
          surface: MatteColors.bgCard,
          onSurface: MatteColors.textPrimary,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const SkyePlayShell(),
    );
  }
}

class SkyePlayShell extends StatefulWidget {
  const SkyePlayShell({super.key});
  @override
  State<SkyePlayShell> createState() => _SkyePlayShellState();
}

class _SkyePlayShellState extends State<SkyePlayShell> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final playback = ServiceProvider.of(context).playback;
    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        return Scaffold(
          body: GrainOverlay(
            child: Row(
              children: [
                _SideNav(
                  currentIndex: _currentTab,
                  onTap: (i) => setState(() => _currentTab = i),
                ),
                Container(width: 0.5, color: MatteColors.border),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: IndexedStack(
                          index: _currentTab,
                          children: const [
                            SearchScreen(),
                            LibraryScreen(),
                            DownloadsScreen(),
                          ],
                        ),
                      ),
                      if (playback.hasTrack)
                        _MiniPlayer(
                          playback: playback,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    NowPlayingScreen(playback: playback),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Side Nav components below would be unchanged but kept for completeness in main.dart if they were there ──
// Actually I'll just keep the necessary parts to make it compile.
// I'll grab the rest of main.dart from my memory/previous view.

class _SideNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _SideNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      color: MatteColors.bg,
      child: Column(
        children: [
          const SizedBox(height: 14),
          _NavItem(
            icon: Icons.search_rounded,
            label: 'Search',
            isActive: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.library_music_rounded,
            label: 'Library',
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: Icons.download_rounded,
            label: 'Offline',
            isActive: currentIndex == 2,
            onTap: () => onTap(2),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            Icon(
              icon,
              size: 19,
              color: isActive ? MatteColors.accent : MatteColors.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                color: isActive
                    ? MatteColors.textSecondary
                    : MatteColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  final PlaybackState playback;
  final VoidCallback onTap;
  const _MiniPlayer({required this.playback, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        color: MatteColors.bgCard,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.music_note, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                playback.currentTitle ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: playback.togglePlay,
              icon: Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
          ],
        ),
      ),
    );
  }
}
