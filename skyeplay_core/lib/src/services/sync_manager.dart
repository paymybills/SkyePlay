import 'dart:async';
import 'package:skyeplay_core/src/database/database.dart';
import 'package:skyeplay_core/src/services/download_manager.dart';
import 'package:skyeplay_core/src/services/discovery_service.dart';
import 'package:skyeplay_core/src/services/recommender_engine.dart';
import 'package:drift/drift.dart';

class SyncManager {
  final SkyeplayDatabase _db;
  final DownloadManager _downloadManager;
  final DiscoveryService _discoveryService;
  final RecommenderEngine _recommender;

  Timer? _timer;
  bool _isSyncing = false;

  // Configuration
  static const int minQueueSize = 5;
  static const Duration syncInterval = Duration(seconds: 30);

  SyncManager(
    this._db,
    this._downloadManager,
    this._discoveryService,
    this._recommender,
  );

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(syncInterval, (_) => checkQueue());
    print("SyncManager started.");
    checkQueue(); // Run immediately
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    print("SyncManager stopped.");
  }

  Future<void> checkQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // 1. Check Queue Size (Pending + Downloading)
      final queueCount = await (_db.select(_db.downloads)
            ..where((t) => t.status.isIn([0, 1]))) // 0=Pending, 1=Downloading
          .get()
          .then((l) => l.length);

      if (queueCount >= minQueueSize) {
        // print("Queue full ($queueCount/$minQueueSize). Skipping sync.");
        return;
      }

      print("Queue low ($queueCount/$minQueueSize). finding music...");

      // 2. Get Seed (Last added download)
      final lastDownload = await (_db.select(_db.downloads)
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
            ..limit(1))
          .getSingleOrNull();

      String? seedId = lastDownload?.id;
      
      // 3. Get Recommendation
      print("Asking Recommender (Seed: $seedId)...");
      final nextTrack = await _recommender.nextTrack(currentTrackId: seedId);

      if (nextTrack != null) {
        print("Recommended: ${nextTrack.name} by ${nextTrack.artists.first.name}");
        
        // 4. Queue Download
        await _downloadManager.queueDownload(nextTrack);
        
        // 5. Harvest (Expand Graph)
        // We do this in background so we don't block the sync loop too long
        _discoveryService.harvest(nextTrack.id).then((_) {
          print("Harvested connections for ${nextTrack.name}");
        }).catchError((e) {
          print("Harvest failed: $e");
        });
      } else {
        print("Recommender returned null.");
      }
    } catch (e) {
      print("SyncManager Error: $e");
    } finally {
      _isSyncing = false;
    }
  }
}
