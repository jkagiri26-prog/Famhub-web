/// ============================================================
/// INVENTORY SUMMARY (DOMAIN MODEL)
/// ============================================================
///
/// Compact aggregate derived from the active business's inventory list.
/// Counts are display-only and computed client-side from canonical
/// `commerce.stock_registry` rows.
///
/// No total-quantity cross-unit aggregation is attempted (kg + litres +
/// pieces are not safely summable); totals are only shown per-row with
/// their unit.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import '../entities/inventory_item.dart';

class InventorySummary {
  /// Number of stock records returned.
  final int recordCount;

  /// Number of distinct variants referenced by the rows (best-effort).
  final int variantCount;

  /// Number of records that are out of stock.
  final int outOfStockCount;

  /// Number of archived records.
  final int archivedCount;

  const InventorySummary({
    required this.recordCount,
    required this.variantCount,
    required this.outOfStockCount,
    required this.archivedCount,
  });

  factory InventorySummary.from(List<InventoryItem> items) {
    final variantIds = <String>{};
    for (final item in items) {
      final id = item.variantId;
      if (id != null && id.isNotEmpty) variantIds.add(id);
    }
    return InventorySummary(
      recordCount: items.length,
      variantCount: variantIds.length,
      outOfStockCount: items.where((i) => i.isOutOfStock).length,
      archivedCount: items.where((i) => i.isArchived).length,
    );
  }
}
