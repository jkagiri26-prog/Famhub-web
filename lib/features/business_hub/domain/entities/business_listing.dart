/// ============================================================
/// BUSINESS LISTING (DOMAIN)
/// ============================================================
///
/// Read/management view of ONE row of `marketplace.listings` for the
/// Business Hub (business-level visibility surface).
///
/// This entity is a COMPOSITION over the existing Marketplace `Listing`
/// domain entity (via `MarketplaceRepository.fetchListings`) plus the
/// resolved variant display name (core.item_variants). It deliberately
/// adds no new listing logic and no second catalog:
///
///   Marketplace = specialized marketplace experience
///   Business Hub = business-level visibility/control surface
///
/// Actual documented `marketplace.listings` columns used (see
/// docs/Backend schemas/marketplace schema.md):
///   id, entity_id, title, description, unit_id, price_per_unit,
///   currency, location_id, status, contact_visibility, is_promoted,
///   promoted_until, images, created_at, updated_at, stock_id,
///   variant_id
///
/// Stock availability shown here comes from the listing's linked
/// `commerce.stock_registry` row (exposed by the Marketplace repository)
/// — no Business Hub inventory logic is created.
///
/// Listing status values are the Marketplace `ListingStatus` enum
/// (draft | active | paused | sold_out | archived | inactive) — nothing
/// is invented.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/marketplace/domain/enums/listing_status.dart';

class BusinessListing {
  final String id;
  final String title;
  final String? description;
  final double pricePerUnit;
  final String currency;
  final List<String> images;

  /// Owning entity (marketplace.listings.entity_id → core.entities).
  final String entityId;

  /// FK → core.item_variants.
  final String? variantId;

  /// Resolved variant display name (core.item_variants).
  final String? variantName;

  /// FK → commerce.stock_registry (sell-side offer over inventory).
  final String? stockId;

  final String? unitId;
  final String? unitName;
  final String? locationId;
  final String? locationName;

  /// Availability resolved from the linked stock row.
  final double availableQuantity;
  final double reservedQuantity;

  final ListingStatus status;
  final bool isPromoted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BusinessListing({
    required this.id,
    required this.title,
    this.description,
    required this.pricePerUnit,
    this.currency = 'KES',
    this.images = const [],
    required this.entityId,
    this.variantId,
    this.variantName,
    this.stockId,
    this.unitId,
    this.unitName,
    this.locationId,
    this.locationName,
    this.availableQuantity = 0,
    this.reservedQuantity = 0,
    this.status = ListingStatus.draft,
    this.isPromoted = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Build a Business Hub listing view from an existing Marketplace
  /// [Listing], enriching the variant display name when available.
  factory BusinessListing.fromMarketplace(
    Listing listing, {
    String? variantName,
  }) {
    return BusinessListing(
      id: listing.id,
      title: listing.title,
      description: listing.description,
      pricePerUnit: listing.pricePerUnit,
      currency: listing.currency,
      images: listing.images,
      entityId: listing.entityId,
      variantId: listing.variantId,
      variantName: variantName,
      stockId: listing.stockId,
      unitId: listing.unitId,
      unitName: listing.unitName,
      locationId: listing.locationId,
      locationName: listing.locationName,
      availableQuantity: listing.availableQuantity,
      reservedQuantity: listing.reservedQuantity,
      status: listing.status,
      isPromoted: listing.isPromoted,
      createdAt: listing.createdAt,
      updatedAt: listing.updatedAt,
    );
  }

  /// Primary label: prefer the canonical item/variant name, fall back to
  /// the listing title.
  String get displayItem {
    final variant = variantName;
    if (variant != null && variant.trim().isNotEmpty) return variant.trim();
    return title;
  }

  /// Price + unit, e.g. "KES 650 /kg".
  String get displayPrice {
    final price = pricePerUnit == pricePerUnit.roundToDouble()
        ? pricePerUnit.toInt().toString()
        : pricePerUnit.toStringAsFixed(2);
    final unit = unitName;
    return unit != null && unit.trim().isNotEmpty
        ? '${currency.trim()} $price /${unit.trim()}'
        : '${currency.trim()} $price';
  }

  bool get isActive => status == ListingStatus.active;

  bool get isSoldOut => availableQuantity <= 0;

  String get displayLocation =>
      (locationName != null && locationName!.trim().isNotEmpty)
          ? locationName!.trim()
          : '—';
}
