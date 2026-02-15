part of 'metadata.dart';

@freezed
class SpotubeImageObject with _$SpotubeImageObject {
  factory SpotubeImageObject({
    required String url,
    int? width,
    int? height,
  }) = _SpotubeImageObject;

  factory SpotubeImageObject.fromJson(Map<String, dynamic> json) =>
      _$SpotubeImageObjectFromJson(json);
}

enum ImagePlaceholder {
  albumArt,
  artist,
  collection,
  online,
}

const placeholderUrlMap = {
  ImagePlaceholder.albumArt: "",
  ImagePlaceholder.artist: "",
  ImagePlaceholder.collection: "",
  ImagePlaceholder.online: "",
};

extension SpotubeImageExtensions on List<SpotubeImageObject>? {
  /// Returns the URL of the image at the specified index.
  String asUrlString({
    int index = 1,
    required ImagePlaceholder placeholder,
  }) {
    final sortedImage = this?.sorted((a, b) => a.width!.compareTo(b.width!));

    return sortedImage != null && sortedImage.isNotEmpty
        ? sortedImage[
                index > sortedImage.length - 1 ? sortedImage.length - 1 : index]
            .url
        : placeholderUrlMap[placeholder]!;
  }

  Uri asUri({
    int index = 1,
    required ImagePlaceholder placeholder,
  }) {
    final url = asUrlString(placeholder: placeholder, index: index);
    if (url.startsWith("http")) {
      return Uri.parse(url);
    }
    return Uri.file(url);
  }

  String smallest(ImagePlaceholder placeholder) {
    final sortedImage = this?.sorted((a, b) {
      final widthComparison = (a.width ?? 0).compareTo(b.width ?? 0);
      if (widthComparison != 0) return widthComparison;
      return (a.height ?? 0).compareTo(b.height ?? 0);
    });

    return sortedImage != null && sortedImage.isNotEmpty
        ? sortedImage.first.url
        : placeholderUrlMap[placeholder]!;
  }
}
