/// ============================================================
/// LISTING MAPPER — Contract Alignment
/// ============================================================
///
/// Maps between backend JSON (marketplace.listings + FK joins)
/// and the domain Listing entity.
///
/// This is the ONLY layer aware of backend column names.
/// ============================================================

import '../../domain/entities/listing.dart';
import '../../domain/enums/listing_status.dart';

class ListingMapper {
  /// Deserialize a raw JSON map into a Listing entity.
  ///
  /// Expects the PostgREST join shape:
  /// {
  ///   "id": "...",
  ///   "title": "...",
  ///   "description": "...",
  ///   "price_per_unit": 1500.0,
  ///   "currency": "KES",
  ///   "status": "active",
  ///   "images": ["url1", "url2"],
  ///   "contact_visibility": "locked",
  ///   "is_promoted": false,
  ///   "promoted_until": null,
  ///   "created_at": "2024-01-01T00:00:00Z",
  ///   "updated_at": "2024-01-01T00:00:00Z",
  ///   "entity_id": "...",
  ///   "variant_id": "...",
  ///   "stock_id": "...",
  ///   "unit_id": "...",
  ///   "location_id": "...",
  ///   "unit": { "name": "kg" },
  ///   "location": { "name": "Nairobi" },
  ///   "stock": { "quantity": 100, "reserved_quantity": 5 }
  /// }
  static Listing fromJson(Map<String, dynamic> json) {
    final unitData = json['unit'];
    final locationData = json['location'];
    final stockData = json['stock'];

    return Listing(
      // Persisted fields
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'KES',
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      entityId: json['entity_id']?.toString() ?? '',
      variantId: json['variant_id']?.toString() ?? '',
      stockId: json['stock_id']?.toString() ?? '',
      unitId: json['unit_id']?.toString(),
      locationId: json['location_id']?.toString(),
      contactVisibility: json['contact_visibility']?.toString() ?? 'locked',
      isPromoted: json['is_promoted'] == true,
      promotedUntil: json['promoted_until'] != null
          ? DateTime.parse(json['promoted_until'].toString())
          : null,
      status: ListingStatus.fromString(json['status']?.toString()),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      // Resolved fields from joins
      unitName: unitData is Map<String, dynamic>
          ? unitData['name']?.toString()
          : null,
      locationName: locationData is Map<String, dynamic>
          ? locationData['name']?.toString()
          : null,
      sellerName: json['seller_name']?.toString(),
      sellerRating: (json['seller_rating'] as num?)?.toDouble(),
      availableQuantity: stockData is Map<String, dynamic>
          ? (stockData['quantity'] as num?)?.toDouble() ?? 0
          : 0,
      reservedQuantity: stockData is Map<String, dynamic>
          ? (stockData['reserved_quantity'] as num?)?.toDouble() ?? 0
          : 0,
    );
  }

  /// Serialize Listing to a payload for create/update mutations.
  /// Only includes persisted (writable) fields.
  static Map<String, dynamic> toJson(Listing listing) {
    return {
      'title': listing.title,
      'description': listing.description,
      'price_per_unit': listing.pricePerUnit,
      'currency': listing.currency,
      'images': listing.images,
      'entity_id': listing.entityId,
      'variant_id': listing.variantId,
      'stock_id': listing.stockId,
      'unit_id': listing.unitId,
      'location_id': listing.locationId,
      'contact_visibility': listing.contactVisibility,
      'is_promoted': listing.isPromoted,
      'promoted_until': listing.promotedUntil?.toIso8601String(),
    };
  }
}
