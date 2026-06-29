/// ============================================================
/// LISTING STATUS ENUM
/// ============================================================
///
/// Typed listing status enum for marketplace listings.
/// Moved from domain/entities/listing.dart per architecture standard.
/// ============================================================
library;

enum ListingStatus {
  draft,
  active,
  paused,
  soldOut,
  archived;

  String get value {
    switch (this) {
      case ListingStatus.draft:
        return 'draft';
      case ListingStatus.active:
        return 'active';
      case ListingStatus.paused:
        return 'paused';
      case ListingStatus.soldOut:
        return 'sold_out';
      case ListingStatus.archived:
        return 'archived';
    }
  }

  static ListingStatus fromString(String? value) {
    switch (value) {
      case 'draft':
        return ListingStatus.draft;
      case 'active':
        return ListingStatus.active;
      case 'paused':
        return ListingStatus.paused;
      case 'sold_out':
        return ListingStatus.soldOut;
      case 'archived':
        return ListingStatus.archived;
      default:
        return ListingStatus.draft;
    }
  }

  bool get isListable => this == ListingStatus.active;
  bool get isEditable =>
      this == ListingStatus.draft || this == ListingStatus.paused;
}
