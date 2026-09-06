import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/models/listing_publication.dart';

/// ============================================================
/// LISTING EDIT — STAGED IMAGE CHANGES (DOMAIN)
/// ============================================================
///
/// Describes the photo edits a seller has staged while editing a listing.
/// Nothing here is persisted by itself: the Listing Edit Save flow reads this
/// draft and commits it through the hardened media flow (`upload_media` /
/// `delete_media`). The client never writes `marketplace.listings.images`.
///
/// Identity is the existing marketplace media identity:
///   - existing photos → `media.files.id` (via `ListingImageFile`)
///   - new photos      → prepared `SelectedListingImage` payloads
///
/// Signed URLs are never part of this comparison.
/// ============================================================
class ListingEditImagesState {
  /// Photos prepared this session that should be uploaded on Save.
  final List<SelectedListingImage> addedImages;

  /// `media.files.id` values of existing photos staged for removal.
  final Set<String> removedIds;

  const ListingEditImagesState({
    this.addedImages = const [],
    this.removedIds = const {},
  });

  /// A listing edit is dirty as soon as any image is staged for addition or
  /// removal. A picker that opens and closes without staging anything never
  /// marks the form dirty.
  bool get hasChanges => addedImages.isNotEmpty || removedIds.isNotEmpty;

  int get addedCount => addedImages.length;

  int get removedCount => removedIds.length;

  bool get isEmpty => addedImages.isEmpty && removedIds.isEmpty;
}

/// ============================================================
/// LISTING EDIT — SAVE REPORT (DOMAIN)
/// ============================================================
///
/// Truthful outcome of committing a Listing Edit Save. Save is never reported
/// as a full success when some work failed: [metadataError] / [imageFailures]
/// carry the partial result so callers can report it accurately without
/// pretending the complete save succeeded.
/// ============================================================
class ListingEditSaveReport {
  /// The updated listing when metadata was successfully applied.
  final Listing? updatedListing;

  /// Set when the metadata update failed.
  final Object? metadataError;

  /// Number of staged additions actually uploaded.
  final int uploadedCount;

  /// Number of staged removals actually deleted.
  final int removedCount;

  /// Upload / delete failures, one entry per failed image operation.
  final List<String> imageFailures;

  const ListingEditSaveReport({
    this.updatedListing,
    this.metadataError,
    this.uploadedCount = 0,
    this.removedCount = 0,
    this.imageFailures = const [],
  });

  bool get metadataSaved => metadataError == null;

  bool get allImagesSaved => imageFailures.isEmpty;

  bool get allSaved => metadataSaved && allImagesSaved;
}
