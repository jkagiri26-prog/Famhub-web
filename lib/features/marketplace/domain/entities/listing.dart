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
///     - seller_id (uuid, nullable)
///     - seller_name (text, nullable)
///     - seller_rating (numeric, nullable)
///     - available_quantity (numeric)
///     - sold_quantity (numeric)
///     - reserved_quantity (numeric)
///     - status (text) — draft | active | paused | sold_out | archived
///     - created_at (timestamptz)
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

/// Typed listing status enum.
enum ListingStatus {
  draft,
  active,
  paused,
  soldOut,
  archived;

  String get value {
    switch (this) {
      case ListingStatus.draft: return 'draft';
      case ListingStatus.active: return 'active';
      case ListingStatus.paused: return 'paused';
      case ListingStatus.soldOut: return 'sold_out';
      case ListingStatus.archived: return 'archived';
    }
  }

  static ListingStatus fromString(String? value) {
    switch (value) {
      case 'draft': return ListingStatus.draft;
      case 'active': return ListingStatus.active;
      case 'paused': return ListingStatus.paused;
      case 'sold_out': return ListingStatus.soldOut;
      case 'archived': return ListingStatus.archived;
      default: return ListingStatus.draft;
    }
  }

  bool get isListable => this == ListingStatus.active;
  bool get isEditable => this == ListingStatus.draft || this == ListingStatus.paused;
}

class Listing {
  final String id;
  final String title;
  final String? description;
  final double price;
  final String unit;
  final List<String> images;
  final String? location;
  final String? sellerId;
  final String? sellerName;
  final double? sellerRating;
  final double availableQuantity;
  final double soldQuantity;
  final double reservedQuantity;
  final ListingStatus status;
  final DateTime createdAt;

  Listing({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.unit,
    required this.images,
    this.location,
    this.sellerId,
    this.sellerName,
    this.sellerRating,
    this.availableQuantity = 0,
    this.soldQuantity = 0,
    this.reservedQuantity = 0,
    this.status = ListingStatus.active,
    required this.createdAt,
  });

  /// True when available quantity is at or below zero.
  bool get isSoldOut => availableQuantity <= 0;

  /// True when available quantity is low (below threshold).
  bool isLowStock(double threshold) => availableQuantity <= threshold && availableQuantity > 0;

  Listing copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? unit,
    List<String>? images,
    String? location,
    String? sellerId,
    String? sellerName,
    double? sellerRating,
    double? availableQuantity,
    double? soldQuantity,
    double? reservedQuantity,
    ListingStatus? status,
    DateTime? createdAt,
  }) {
    return Listing(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      images: images ?? this.images,
      location: location ?? this.location,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerRating: sellerRating ?? this.sellerRating,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      soldQuantity: soldQuantity ?? this.soldQuantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
