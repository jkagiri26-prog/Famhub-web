/// ============================================================
/// LISTING ENTITY (DOMAIN)
/// ============================================================
///
/// Pure domain entity for marketplace listings.
///
/// Schema source:
///   marketplace.listings:
///     - id (uuid)
///     - title (text)
///     - description (text, nullable)
///     - price (numeric)
///     - unit (text)
///     - images (text[])
///     - location (text, nullable)
///     - seller_name (text, nullable)
///     - seller_rating (numeric, nullable)
///     - available (text, nullable)
///     - created_at (timestamptz)
/// ============================================================

class Listing {
  final String id;
  final String title;
  final String? description;
  final double price;
  final String unit;
  final List<String> images;
  final String? location;
  final String? sellerName;
  final double? sellerRating;
  final String? available;
  final DateTime createdAt;

  Listing({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.unit,
    required this.images,
    this.location,
    this.sellerName,
    this.sellerRating,
    this.available,
    required this.createdAt,
  });
}