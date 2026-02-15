import 'dart:io';
import 'package:skyeplay_core/src/database/database.dart';
import 'package:drift/drift.dart';

class PruningService {
  final SkyeplayDatabase _db;
  final int maxSongsWithFiles;

  PruningService(this._db, {this.maxSongsWithFiles = 100});

  /// Prunes downloaded files for the lowest-scored songs when storage exceeds quota.
  /// Songs are kept in the graph (for recommendations) but their files are deleted.
  /// Returns the number of files pruned.
  Future<int> prune() async {
    // 1. Count songs that have local files
    final songsWithFiles = await (_db.select(_db.songs)
          ..where((s) => s.filePath.isNotNull()))
        .get();

    final excess = songsWithFiles.length - maxSongsWithFiles;
    if (excess <= 0) return 0;

    print("Pruning: $excess songs over quota (${songsWithFiles.length}/$maxSongsWithFiles)");

    // 2. Rank by eviction priority: lowest score first, then oldest lastPlayed
    //    Never prune "pinned" songs (score > 100 as a simple heuristic)
    final candidates = await _db.customSelect(
      '''
      SELECT id, file_path, score, last_played 
      FROM songs 
      WHERE file_path IS NOT NULL AND score <= 100
      ORDER BY score ASC, last_played ASC
      LIMIT ?
      ''',
      variables: [Variable.withInt(excess)],
    ).get();

    int pruned = 0;
    for (final row in candidates) {
      final id = row.read<String>('id');
      final filePath = row.read<String>('file_path');

      // Delete file
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          print("Pruned file: $filePath");
        }
      } catch (e) {
        print("Failed to delete $filePath: $e");
      }

      // Clear filePath in DB (keep song in graph for recommendations)
      await (_db.update(_db.songs)..where((s) => s.id.equals(id))).write(
        const SongsCompanion(filePath: Value(null)),
      );

      // Also remove from downloads table
      await (_db.delete(_db.downloads)..where((d) => d.id.equals(id))).go();

      pruned++;
    }

    print("Pruned $pruned songs.");
    return pruned;
  }
}
