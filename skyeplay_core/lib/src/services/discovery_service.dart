import 'dart:convert';
import 'package:skyeplay_core/src/database/database.dart';
import 'package:skyeplay_core/src/metadata/metadata.dart';
import 'package:skyeplay_core/src/metadata/models/metadata.dart';
import 'package:skyeplay_core/src/database/schema.dart';
import 'package:drift/drift.dart';

class DiscoveryService {
  final SkyeplayDatabase _db;
  final MetadataPlugin _metadata;

  DiscoveryService(this._db, this._metadata);

  /// Harvests related tracks based on a seed track and stores them in the graph.
  Future<void> harvest(String seedTrackId) async {
    print("Harvesting from seed: $seedTrackId");
    
    // 1. Fetch related tracks from MetadataPlugin
    // Ideally we'd have a 'related' endpoint on track or artist. 
    // Since we only have 'search' and 'audioSource' in the mock so far, 
    // let's assume we use 'search' with the artist name as a proxy for "related" 
    // OR we implement a 'related' endpoint in the plugin/mock.
    // For PoC, let's try to get the track from DB to get its artist, then search for that artist.
    
    final seedSong = await (_db.select(_db.songs)..where((t) => t.id.equals(seedTrackId))).getSingleOrNull();
    if (seedSong == null) {
      print("Seed song not found in DB");
      return;
    }

    final seedTrack = SpotubeFullTrackObject.fromJson(jsonDecode(seedSong.trackJson));
    final query = seedTrack.artists.first.name; // Simple strategy: Search artist
    
    final results = await _metadata.search.all(query);
    
    print("Found ${results.tracks.length} related tracks");

    // 2. Insert into Graph
    for (final track in results.tracks) {
      // Skip if same as seed
      if (track.id == seedTrackId) continue;
      
      // Safe insert: Don't overwrite existing stats
      await _db.into(_db.songs).insert(SongsCompanion.insert(
        id: track.id, // Value() not needed for .insert constructor usually? Wait, let's use named args
        title: track.name,
        artist: track.artists.first.name,
        trackJson: jsonEncode(track.toJson()),
        createdAt: Value(DateTime.now()),
      ), mode: InsertMode.insertOrIgnore);

      // 3. Insert Edge
      // We want to ensure the edge exists.
      await _db.into(_db.edges).insert(EdgesCompanion.insert(
        sourceId: seedTrackId,
        targetId: track.id,
        weight: const Value(1.0),
        createdAt: Value(DateTime.now()),
      ), mode: InsertMode.insertOrIgnore);
    }
  }
}
