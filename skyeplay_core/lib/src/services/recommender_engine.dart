import 'dart:math';
import 'dart:convert';
import 'package:skyeplay_core/src/database/database.dart';
import 'package:skyeplay_core/src/metadata/models/metadata.dart';
import 'package:drift/drift.dart';

class RecommenderEngine {
  final SkyeplayDatabase _db;
  final Random _rng = Random();

  RecommenderEngine(this._db);

  /// Decides the next track to play.
  /// [currentTrackId] is the ID of the currently playing track (optional).
  Future<SpotubeFullTrackObject?> nextTrack({String? currentTrackId}) async {
    // 1. If no current track, or 15% chance, do a Random Jump (Exploration)
    if (currentTrackId == null || _rng.nextDouble() < 0.15) {
      print("Recommender: Random Jump (Exploration)");
      return _randomTrack();
    }

    // 2. Exploitation: Probabilistic Walk from current track
    print("Recommender: Probabilistic Walk from $currentTrackId");
    
    // Fetch neighbors
    final edges = await (_db.select(_db.edges)..where((e) => e.sourceId.equals(currentTrackId))).get();
    
    if (edges.isEmpty) {
      print("Recommender: Dead end, falling back to Random");
      return _randomTrack();
    }

    // 3. Calculate Weights
    // For now, just use edge weight. 
    // TODO: Factor in play_count decay (anti-repetition)
    
    double totalWeight = edges.fold(0, (sum, e) => sum + e.weight);
    double randomPoint = _rng.nextDouble() * totalWeight;
    
    // Select based on weight
    double currentSum = 0;
    for (final edge in edges) {
      currentSum += edge.weight;
      if (currentSum >= randomPoint) {
         final target = await (_db.select(_db.songs)..where((s) => s.id.equals(edge.targetId))).getSingleOrNull();
         if (target != null) {
           return SpotubeFullTrackObject.fromJson(jsonDecode(target.trackJson));
         }
      }
    }
    
    // Fallback
    return _randomTrack();
  }

  Future<SpotubeFullTrackObject?> _randomTrack() async {
    // Drift doesn't support ORDER BY RANDOM() easily in cross-platform without custom query
    // But for PoC with small DB, we can fetch IDs or use custom SQL.
    // Let's use custom SQL for efficiency.
    
    final result = await _db.customSelect('SELECT * FROM songs ORDER BY RANDOM() LIMIT 1').getSingleOrNull();
    
    if (result != null) {
       // Convert Row to Song? 
       // Drift generated classes have mapping.
       // SongsData (row class) can be created? 
       // Or just parse JSON manually since we know the column.
       final jsonStr = result.read<String>('track_json');
       return SpotubeFullTrackObject.fromJson(jsonDecode(jsonStr));
    }
    return null;
  }
}
