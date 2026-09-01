/// ============================================================
/// STOCK ITEM ENTITY (DOMAIN)
/// ============================================================
///
/// Pure domain entity for managed stock sourced from
/// `commerce.stock_registry` — the existing inventory system.
///
/// The client never submits `entity_id`, `variant_id`, `unit_id` or
/// `location_id`; those are resolved server-side by the
/// `marketplace.publish_listing_from_stock` RPC under RLS.
///
/// Resolved fields (via PostgREST FK joins at query time):
///   - product/variant (core.item_variants → core.items)
///   - unit (core.units.name)
///   - location (core.locations.name)
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class StockItem {
  /// Stock record id (commerce.stock_registry.id).
  final String id;

  /// Owning entity (resolved by RLS — never submitted by the client).
  final String entityId;

  /// FK to core.item_variants.
  final String? variantId;

  /// Resolved product/variant display name.
  final String? productName;

  /// FK to core.units.
  final String? unitId;

  /// Resolved unit display name (core.units.name).
  final String? unitName;

  /// FK to core.locations.
  final String? locationId;

  /// Resolved location display name (core.locations.name).
  final String? locationName;

  /// Total on-hand quantity.
  final double quantity;

  /// Reserved (committed) quantity.
  final double reservedQuantity;

  const StockItem({
    required this.id,
    required this.entityId,
    this.variantId,
    this.productName,
    this.unitId,
    this.unitName,
    this.locationId,
    this.locationName,
    this.quantity = 0,
    this.reservedQuantity = 0,
  });

  /// Quantity available for new listings: on-hand minus reserved.
  double get availableQuantity {
    final available = quantity - reservedQuantity;
    return available > 0 ? available : 0;
  }

  /// Whether this stock can be listed (has sellable quantity).
  bool get isEligible => availableQuantity > 0;

  /// Display-friendly product name, with a sensible fallback.
  String get displayName =>
      (productName != null && productName!.trim().isNotEmpty)
          ? productName!.trim()
          : 'Stock item';

  /// Location fallback for display.
  String get displayLocation =>
      (locationName != null && locationName!.trim().isNotEmpty)
          ? locationName!.trim()
          : '—';

  /// Unit fallback for display.
  String get displayUnit =>
      (unitName != null && unitName!.trim().isNotEmpty)
          ? unitName!.trim()
          : '—';

  StockItem copyWith({
    String? id,
    String? entityId,
    String? variantId,
    String? productName,
    String? unitId,
    String? unitName,
    String? locationId,
    String? locationName,
    double? quantity,
    double? reservedQuantity,
  }) {
    return StockItem(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      variantId: variantId ?? this.variantId,
      productName: productName ?? this.productName,
      unitId: unitId ?? this.unitId,
      unitName: unitName ?? this.unitName,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      quantity: quantity ?? this.quantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
    );
  }
}
