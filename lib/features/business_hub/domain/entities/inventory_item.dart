/// ============================================================
/// INVENTORY ITEM (DOMAIN)
/// ============================================================
///
/// Read model for ONE row of `commerce.stock_registry` — the canonical
/// inventory table. Business Hub does NOT create a duplicate inventory
/// table or an alternative inventory model; this entity is only the
/// frontend view of an existing stock_registry row.
///
/// Resolved fields (display names) come from the canonical taxonomy:
///   - product/variant name ← core.item_variants / core.items
///   - unit name            ← core.units
///   - location name        ← core.locations
/// via batched scalar lookups (no cross-schema FK embeds).
///
/// Ownership (`entity_id`) is resolved server-side by RLS. The client
/// never supplies a `user_id`; it only scopes reads to the active
/// business entity id it already can see.
///
/// Schema source: docs/Backend schemas/commerce schema.md
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class InventoryItem {
  /// commerce.stock_registry.id
  final String id;

  /// Owning entity (commerce.stock_registry.entity_id).
  final String entityId;

  /// Optional business profile owning the row.
  final String? businessProfileId;

  /// FK to core.item_variants.
  final String? variantId;

  /// Optional FK/product reference to core.items (column: product_id).
  final String? productId;

  /// Resolved product/variant display name.
  final String? displayName;

  /// FK to core.units.
  final String? unitId;

  /// Resolved unit display name (core.units.name).
  final String? unitName;

  /// FK to core.locations.
  final String? locationId;

  /// Resolved location display name (core.locations.name).
  final String? locationName;

  /// On-hand quantity.
  final double quantity;

  /// Reserved (committed) quantity.
  final double reservedQuantity;

  /// Raw status: active | depleted | archived.
  final String status;

  const InventoryItem({
    required this.id,
    required this.entityId,
    this.businessProfileId,
    this.variantId,
    this.productId,
    this.displayName,
    this.unitId,
    this.unitName,
    this.locationId,
    this.locationName,
    this.quantity = 0,
    this.reservedQuantity = 0,
    this.status = 'active',
  });

  /// Quantity available for use: on-hand minus reserved (floor at 0).
  double get availableQuantity {
    final available = quantity - reservedQuantity;
    return available > 0 ? available : 0;
  }

  /// Out of stock when nothing is on hand or everything is committed.
  bool get isOutOfStock => quantity <= 0 || availableQuantity <= 0;

  bool get isArchived => status == 'archived';

  bool get isDepleted => status == 'depleted';

  /// Display fallback for an unnamed stock row.
  String get displayLabel =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : 'Stock item';

  /// Display fallback for unit.
  String get displayUnit =>
      (unitName != null && unitName!.trim().isNotEmpty)
          ? unitName!.trim()
          : '';

  /// Display fallback for location.
  String get displayLocation =>
      (locationName != null && locationName!.trim().isNotEmpty)
          ? locationName!.trim()
          : '—';
}
