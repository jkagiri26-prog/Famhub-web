import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../domain/models/listing_publication.dart';

class ListingImageException implements Exception {
  final String message;
  const ListingImageException(this.message);

  @override
  String toString() => message;
}

class ListingImageOversizedException extends ListingImageException {
  const ListingImageOversizedException(super.message);
}

class ListingImageUnsupportedException extends ListingImageException {
  const ListingImageUnsupportedException(super.message);
}

class ListingImageProcessingException extends ListingImageException {
  const ListingImageProcessingException(super.message);
}

/// Prepares seller-selected photos for the `upload_media` contract.
///
/// Guarantees every produced [SelectedListingImage] is WebP encoded and at or
/// below the 2 MB per-image limit. Unsupported or oversized sources are
/// rejected before upload.
class ListingImageProcessingService {
  static const int maxImagesPerListing = 3;
  static const int maxBytesPerImage = 2 * 1024 * 1024;

  const ListingImageProcessingService();

  Future<SelectedListingImage> prepare({
    required Uint8List bytes,
    String? sourceName,
  }) async {
    if (bytes.isEmpty) {
      throw const ListingImageUnsupportedException(
        'That file is empty. Choose a different photo.',
      );
    }
    try {
      return await _encodeWebP(bytes);
    } on MissingPluginException {
      return _acceptOnlyWebP(bytes);
    } on UnsupportedError {
      return _acceptOnlyWebP(bytes);
    } on ListingImageException {
      rethrow;
    } catch (_) {
      throw const ListingImageUnsupportedException(
        'This photo could not be read. Choose a different image.',
      );
    }
  }

  Future<SelectedListingImage> _encodeWebP(Uint8List bytes) async {
    var quality = 90;
    var bound = 1920;
    while (true) {
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: bound,
        minHeight: bound,
        quality: quality,
        format: CompressFormat.webp,
      );
      if (out.isEmpty) {
        throw const ListingImageProcessingException(
          'Could not process the photo. Choose a different image.',
        );
      }
      if (out.lengthInBytes <= maxBytesPerImage) {
        return SelectedListingImage(
          bytes: out,
          fileName: _fileName(out.lengthInBytes),
        );
      }
      if (quality > 45) {
        quality -= 15;
        continue;
      }
      if (bound > 1024) {
        bound = (bound * 0.75).round();
        quality = 80;
        continue;
      }
      throw const ListingImageOversizedException(
        'This photo is larger than 2 MB and cannot be reduced. '
        'Choose a smaller image.',
      );
    }
  }

  SelectedListingImage _acceptOnlyWebP(Uint8List bytes) {
    if (bytes.lengthInBytes > maxBytesPerImage) {
      throw const ListingImageOversizedException(
        'This photo is larger than 2 MB. Choose a smaller image.',
      );
    }
    if (!isWebPBytes(bytes)) {
      throw const ListingImageUnsupportedException(
        'Only WebP images are supported. Choose a .webp photo.',
      );
    }
    return SelectedListingImage(
      bytes: bytes,
      fileName: _fileName(bytes.lengthInBytes),
    );
  }

  static String _fileName(int byteLength) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return 'listing_image_${stamp}_$byteLength.webp';
  }

  /// True when [bytes] carry the WebP container signature (RIFF…WEBP).
  static bool isWebPBytes(Uint8List bytes) {
    if (bytes.lengthInBytes < 12) return false;
    return bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }
}
