import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:skyeplay_core/src/database/database.dart';
import 'package:skyeplay_core/src/metadata/metadata.dart';
import 'package:skyeplay_core/src/metadata/models/metadata.dart';
import 'package:skyeplay_core/src/database/schema.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' as drift;

class DownloadManager {
  final SkyeplayDatabase _db;
  final MetadataPlugin _metadata;
  final String downloadPath;

  DownloadManager(this._db, this._metadata, this.downloadPath);

  Future<void> init() async {
    // Ensure download directory exists
    await Directory(downloadPath).create(recursive: true);
  }

  Future<void> queueDownload(SpotubeFullTrackObject track) async {
    // Check if already exists
    // final exists = await (_db.select(_db.downloads)..where((tbl) => tbl.id.equals(track.id))).getSingleOrNull();
    // if (exists != null) return;

    await _db.into(_db.downloads).insertOnConflictUpdate(DownloadsCompanion.insert(
      id: track.id,
      trackJson: jsonEncode(track.toJson()),
      status: const drift.Value(0), // Pending
      createdAt: drift.Value(DateTime.now()),
      updatedAt: drift.Value(DateTime.now()),
    ));
    
    // Trigger processing (simple async for now)
    _processQueue();
  }

  Future<void> _processQueue() async {
    // Pick next pending download
    final pending = await (_db.select(_db.downloads)
      ..where((t) => t.status.equals(0))
      ..limit(1)
    ).getSingleOrNull();

    if (pending == null) return;

    // Update to downloading
    await (_db.update(_db.downloads)..where((t) => t.id.equals(pending.id))).write(
      DownloadsCompanion(
        status: const drift.Value(1), 
        updatedAt: drift.Value(DateTime.now())
      )
    );

    try {
      final track = SpotubeFullTrackObject.fromJson(jsonDecode(pending.trackJson));
      print("Resolving stream for ${track.name}...");
      
      // Resolve stream
      final matches = await _metadata.audioSource.matches(track);
      if (matches.isEmpty) throw Exception("No matches found");
      
      // Sort matches or pick first?
      final match = matches.first;
      
      final streams = await _metadata.audioSource.streams(match);
      if (streams.isEmpty) throw Exception("No streams found");
      
      // Pick best stream (e.g. highest bitrate)
      streams.sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
      final stream = streams.first;
      
      print("Downloading from ${stream.url}...");
      // Download (Mock implementation for now)
      final fileName = "${track.artists.first.name} - ${track.name}.${stream.container}";
      final filePath = p.join(downloadPath, fileName);
      
      // Simulate download
      // await http.get(Uri.parse(stream.url)); ...
      // For now just create empty file
      await File(filePath).create(); 
      
      // On success:
      await (_db.update(_db.downloads)..where((t) => t.id.equals(pending.id))).write(
        DownloadsCompanion(
          status: const drift.Value(2), 
          progress: const drift.Value(1.0), 
          filePath: drift.Value(filePath),
          updatedAt: drift.Value(DateTime.now())
        )
      );
      print("Download complete: $filePath");
    } catch (e) {
      print("Download failed: $e");
      // On failure
      await (_db.update(_db.downloads)..where((t) => t.id.equals(pending.id))).write(
        DownloadsCompanion(
          status: const drift.Value(3),
          updatedAt: drift.Value(DateTime.now())
        ) 
      );
    } finally {
      // Process next
      _processQueue();
    }
  }

  Future<void> cancelDownload(String trackId) async {
    final download = await (_db.select(_db.downloads)..where((t) => t.id.equals(trackId))).getSingleOrNull();
    if (download == null) return;
    
    // In a real implementation with Dio/HTTP, we would use CancelToken here.
    // For now, we just mark as cancelled/failed or remove.
    // If status is downloading, we should interrupt.
    
    await (_db.update(_db.downloads)..where((t) => t.id.equals(trackId))).write(
       DownloadsCompanion(status: const drift.Value(0)) // Reset to pending? Or delete?
    );
    // Actually, maybe delete from DB if cancelled?
    await (_db.delete(_db.downloads)..where((t) => t.id.equals(trackId))).go();
    
    if (download.filePath != null) {
      final file = File(download.filePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
