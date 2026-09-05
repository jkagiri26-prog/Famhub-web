/// ============================================================
/// LISTING IMAGE FILE (DOMAIN)
/// ============================================================
///
/// A listing photo as resolved through `media_get_by_context`.
///
/// [id] is the `media.files.id` used to delete the photo through
/// `delete_media`. [url] is a temporary signed URL for display only — it is
/// never persisted and must not be written into `Listing.images`.
/// ============================================================
library;

class ListingImageFile {
  final String id;
  final String url;

  const ListingImageFile({
    required this.id,
    required this.url,
  });
}
