import 'dart:typed_data';

import '../entities/listing.dart';

/// A single upload-ready listing image selected by the seller.
///
/// [bytes] are always WebP-encoded and at or below the 2 MB contract limit.
/// [fileName] is the multipart filename used by `upload_media`.
class SelectedListingImage {
  final Uint8List bytes;
  final String fileName;

  const SelectedListingImage({
    required this.bytes,
    required this.fileName,
  });
}

/// Result of publishing a listing from managed stock together with its
/// selected photos.
///
/// The Marketplace listing is always published first (`images = []`). Every
/// selected photo is then uploaded through the hardened `upload_media` flow.
/// [uploadedCount] / [failedCount] describe how many of those uploads
/// succeeded so callers can report partial failures truthfully.
class ListingPublicationReport {
  final Listing listing;
  final int uploadedCount;
  final int failedCount;
  final List<String> failures;

  const ListingPublicationReport({
    required this.listing,
    required this.uploadedCount,
    required this.failedCount,
    required this.failures,
  });

  bool get allImagesUploaded => failedCount == 0;

  int get totalImages => uploadedCount + failedCount;
}
