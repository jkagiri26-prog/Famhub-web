/// ============================================================
/// SALES ORDER LINE (DOMAIN)
/// ============================================================
///
/// Read model for ONE row of `commerce.order_items`, related safely to
/// its parent order via the verified `order_id` FK.
///
/// Actual documented columns (docs/Backend schemas/commerce schema.md):
///   id, order_id (→ commerce.orders), listing_id, product_id (column
///   only — NO FK), quantity, unit (text), price_per_unit,
///   total_amount, created_at, stock_id (→ commerce.stock_registry),
///   variant_id (→ core.item_variants), unit_id (→ core.units)
///
/// Display enrichment uses ONLY verified FKs: `variant_id` (name from
/// core.item_variants) and `unit_id` (name from core.units), falling
/// back to the raw `unit` text. `product_id` is deliberately NOT used as
/// a relationship (no FK exists).
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class SalesOrderLine {
  /// commerce.order_items.id
  final String id;

  /// Parent order id.
  final String orderId;

  /// FK → marketplace.listings (nullable).
  final String? listingId;

  /// FK → core.item_variants (verified relationship).
  final String? variantId;

  /// Resolved variant display name.
  final String? variantName;

  /// FK → core.units.
  final String? unitId;

  /// Resolved unit name (core.units) — fallback to raw `unit` text.
  final String? unitName;

  /// Raw unit text column.
  final String? unitText;

  final double quantity;
  final double pricePerUnit;
  final double totalAmount;

  const SalesOrderLine({
    required this.id,
    required this.orderId,
    this.listingId,
    this.variantId,
    this.variantName,
    this.unitId,
    this.unitName,
    this.unitText,
    this.quantity = 0,
    this.pricePerUnit = 0,
    this.totalAmount = 0,
  });

  /// Item label: variant name, else raw unit-bearing generic label.
  String get displayLabel =>
      (variantName != null && variantName!.trim().isNotEmpty)
          ? variantName!.trim()
          : 'Order item';

  /// Quantity with unit, e.g. "120 kg".
  String get displayQuantity {
    final unit = (unitName != null && unitName!.trim().isNotEmpty)
        ? unitName!.trim()
        : (unitText != null && unitText!.trim().isNotEmpty)
            ? unitText!.trim()
            : '';
    final quantityText = _num(quantity);
    return unit.isEmpty ? quantityText : '$quantityText $unit';
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}
