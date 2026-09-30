/// ============================================================
/// PRICE FAVOURITE (DOMAIN)
/// ============================================================
///
/// A profile-specific market-price favourite from
/// `marketplace.price_favourites`. Ownership is enforced by RLS — the
/// client never submits a profile id.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class PriceFavourite {
  final String id;

  final String? marketId;
  final String? locationId;
  final String? itemId;
  final String? variantId;

  const PriceFavourite({
    required this.id,
    this.marketId,
    this.locationId,
    this.itemId,
    this.variantId,
  });
}
