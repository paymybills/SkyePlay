# SkyePlay - Smart Cache Audio Proxy

A high-performance codebase for YouTube audio streaming on Windows, featuring a robust Smart Cache Proxy architecture.

## The Problem
Direct YouTube streaming often fails due to:
- 403 Forbidden: Network restrictions and session expiration.
- Seeking Deadlocks: Seeking in a DASH stream often causes sequential read deadlocks in playback engines like MPV.
- Connection Drops: Unstable connections break large audio file playback.

## The Solution: Smart Cache Proxy
SkyePlay implements a local loopback proxy that decouples the playback engine from the YouTube network.

### Architecture
1. UI (Flutter) sends a Play ID to PlaybackState.
2. PlaybackState requests a stream via StreamCacheService.
3. StreamCacheService downloads segments from YouTube and manages a local temporary file.
4. PlaybackState hits AudioProxyService via HTTP GET /stream?id=...
5. AudioProxyService serves bytes from the local temporary file.

### Key Components
1. StreamCacheService: Acts as a background download manager. It fetches the DASH manifest and streams audio data directly to a local .m4a file in chunks. It tracks exactly how many bytes are available.
2. AudioProxyService: A local HTTP server. When media_kit (MPV) requests a URL, it hits this proxy.
    - Seeking (Backwards): If the requested range is already downloaded, it serves it instantly from the local file.
    - Seeking (Forwards): If the requested range isn't downloaded yet, it waits briefly (2s) for data. If still unavailable, it returns a 416 Range Not Satisfiable. This forces the player to fail fast rather than hanging indefinitely, ensuring a responsive experience.
3. skyeplay_core: A shared library containing the Drift database schema and core models, ensuring type safety between the app and background services.

## What has been achieved
- Smart Proxy: Loopback server handling complex HTTP Range semantics.
- DASH Streaming: Background segment fetching without blocking the UI.
- State Management: Unified ServiceProvider and PlaybackState for predictable UI updates.
- Persistence: Integration with Drift (SQLite) for library and download tracking.
- Matte UI: A sleek, dark-themed interface for searching and managing offline music.

## Pending and Known Issues
- Larger Audio Files: Current implementation may struggle with very large audio files. This is a known issue that will be addressed in a future update.
- Stream Resumption: Support for resume-on-restart if the cache file is preserved.
- Cache Cleanup: Automatic deletion of least-recently-used cache files to save disk space.
- Playlist Support: Queueing and seamless transition between proxied tracks.

## Setup and Run
1. Clone the repository.
2. Ensure Flutter is installed.
3. Run the application:
   - Navigate to `skyeplay_app` and run `flutter run -d windows`.

---
Built for high-fidelity, reliable audio.
