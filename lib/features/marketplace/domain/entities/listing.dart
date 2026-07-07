/// ============================================================
/// LISTING ENTITY (DOMAIN)
/// ============================================================
///
/// Pure domain entity for marketplace listings.
/// Aligned with marketplace.listings backend schema.
///
/// Persisted fields (stored in DB):
///   id, title, description, pricePerUnit, currency, status, images,
///   entityId, variantId, stockId, unitId, locationId,
///   contactVisibility, isPromoted, promotedUntil, createdAt, updatedAt
///
/// Resolved fields (via FK joins at query time):
///   unitName, locationName, sellerName, sellerRating,
///   availableQuantity, reservedQuantity
///
/// Schema source: docs/Backend schemas/marketplace schema.md
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import '../enums/listing_status.dart';

class Listing {
  // ── Persisted fields (marketplace.listings columns) ──
  final String id;
  final String title;
  final String? description;
  final double pricePerUnit;
  final String currency;
  final List<String> images;
  final String entityId;
  final String variantId;
  final String stockId;
  final String? unitId;
  final String? locationId;
  final String contactVisibility;
  final bool isPromoted;
  final DateTime? promotedUntil;
  final ListingStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Resolved fields (via JOINs) ──
  final String? unitName;
  final String? locationName;
  final String? sellerName;
  final double? sellerRating;
  final double availableQuantity;
  final double reservedQuantity;

  Listing({
    required this.id,
    required this.title,
    this.description,
    required this.pricePerUnit,
    this.currency = 'KES',
    required this.images,
    required this.entityId,
    required this.variantId,
    required this.stockId,
    this.unitId,
    this.locationId,
    this.contactVisibility = 'locked',
    this.isPromoted = false,
    this.promotedUntil,
    this.status = ListingStatus.active,
    required this.createdAt,
    required this.updatedAt,
    // Resolved fields
    this.unitName,
    this.locationName,
    this.sellerName,
    this.sellerRating,
    this.availableQuantity = 0,
    this.reservedQuantity = 0,
  });

  /// True when available quantity is at or below zero.
  bool get isSoldOut => availableQuantity <= 0;

  /// True when available quantity is low (below threshold).
  bool isLowStock(double threshold) =>
      availableQuantity <= threshold && availableQuantity > 0;

  /// Display-friendly price string, e.g. "KSh 1,500/kg"
  String get displayPrice =>
      'KSh ${pricePerUnit.toStringAsFixed(0)}${unitName != null ? '/$unitName' : ''}';

  Listing copyWith({
    String? id,
    String? title,
    String? description,
    double? pricePerUnit,
    String? currency,
    List<String>? images,
    String? entityId,
    String? variantId,
    String? stockId,
    String? unitId,
    String? locationId,
    String? contactVisibility,
    bool? isPromoted,
    DateTime? promotedUntil,
    ListingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? unitName,
    String? locationName,
    String? sellerName,
    double? sellerRating,
    double? availableQuantity,
    double? reservedQuantity,
  }) {
    return Listing(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      currency: currency ?? this.currency,
      images: images ?? this.images,
      entityId: entityId ?? this.entityId,
      variantId: variantId ?? this.variantId,
      stockId: stockId ?? this.stockId,
      unitId: unitId ?? this.unitId,
      locationId: locationId ?? this.locationId,
      contactVisibility: contactVisibility ?? this.contactVisibility,
      isPromoted: isPromoted ?? this.isPromoted,
      promotedUntil: promotedUntil ?? this.promotedUntil,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unitName: unitName ?? this.unitName,
      locationName: locationName ?? this.locationName,
      sellerName: sellerName ?? this.sellerName,
      sellerRating: sellerRating ?? this.sellerRating,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
    );
  }
}

