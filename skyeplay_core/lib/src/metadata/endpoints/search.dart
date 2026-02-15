import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';
import 'package:skyeplay_core/src/metadata/models/metadata.dart';

class MetadataPluginSearchEndpoint {
  final Hetu hetu;
  MetadataPluginSearchEndpoint(this.hetu);

  HTInstance get hetuMetadataSearch =>
      (hetu.fetch("metadataPlugin") as HTInstance).memberGet("search")
          as HTInstance;

  List<String> get chips {
    return (hetuMetadataSearch.memberGet("chips") as List).cast<String>();
  }

  Future<SpotubeSearchResponseObject> all(String query) async {
    if (query.isEmpty) {
      return SpotubeSearchResponseObject(
        albums: [],
        artists: [],
        playlists: [],
        tracks: [],
      );
    }

    final raw = await hetuMetadataSearch.invoke(
      "all",
      positionalArgs: [query],
    ); // Don't cast to Map immediately if it's HTStruct? Wait, invoke returns valid Dart object usually.
       // HTStruct implements Map? No.
       // It seems invoke returns HTStruct which is not Map.
    
    // We expect raw to be HTStruct (or Map structure from script)
    // We should convert it.
    // Actually, let's look at how we handle it.
    
    // If raw is HTStruct, we can use .toJson() if available or cast to dynamic then toJson().
    // SpotubeSearchResponseObject.fromJson expects Map<String, dynamic>.
    
    return SpotubeSearchResponseObject.fromJson((raw as dynamic).toJson());
  }

  Future<SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>> albums(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.invoke(
      "albums",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    );

    return SpotubePaginationResponseObject<SpotubeSimpleAlbumObject>.fromJson(
      (raw as dynamic).toJson(),
      (json) => SpotubeSimpleAlbumObject.fromJson(json.cast<String, dynamic>()),
    );
  }

  Future<SpotubePaginationResponseObject<SpotubeFullArtistObject>> artists(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeFullArtistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.invoke(
      "artists",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    );

    return SpotubePaginationResponseObject<SpotubeFullArtistObject>.fromJson(
      (raw as dynamic).toJson(),
      (json) => SpotubeFullArtistObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }

  Future<SpotubePaginationResponseObject<SpotubeSimplePlaylistObject>>
      playlists(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeSimplePlaylistObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.invoke(
      "playlists",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    );

    return SpotubePaginationResponseObject<
        SpotubeSimplePlaylistObject>.fromJson(
      (raw as dynamic).toJson(),
      (json) => SpotubeSimplePlaylistObject.fromJson(
        json.cast<String, dynamic>(),
      ),
    );
  }

  Future<SpotubePaginationResponseObject<SpotubeFullTrackObject>> tracks(
    String query, {
    int? limit,
    int? offset,
  }) async {
    if (query.isEmpty) {
      return SpotubePaginationResponseObject<SpotubeFullTrackObject>(
        items: [],
        total: 0,
        limit: limit ?? 20,
        hasMore: false,
        nextOffset: null,
      );
    }

    final raw = await hetuMetadataSearch.invoke(
      "tracks",
      positionalArgs: [query],
      namedArgs: {
        "limit": limit,
        "offset": offset,
      }..removeWhere((key, value) => value == null),
    );

    return SpotubePaginationResponseObject<SpotubeFullTrackObject>.fromJson(
      (raw as dynamic).toJson(),
      (json) => SpotubeFullTrackObject.fromJson(json.cast<String, dynamic>()),
    );
  }
}
