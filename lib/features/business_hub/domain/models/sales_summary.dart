/// ============================================================
/// SALES SUMMARY (DOMAIN MODEL)
/// ============================================================
///
/// Compact aggregate derived from the active business's sales order
/// list. Display-only counts computed client-side from canonical
/// `commerce.orders` rows using the documented status enum.
///
/// No revenue totals are fabricated — `commerce.orders` has no currency
/// column, so amounts are never summed across orders here.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import '../entities/sales_order.dart';

class SalesSummary {
  /// Total number of orders.
  final int totalCount;

  /// Open / in-progress orders (pending, confirmed, shipped).
  final int openCount;

  /// Delivered (completed) orders.
  final int completedCount;

  /// Cancelled orders.
  final int cancelledCount;

  /// Returned orders.
  final int returnedCount;

  const SalesSummary({
    required this.totalCount,
    required this.openCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.returnedCount,
  });

  factory SalesSummary.from(List<SalesOrder> orders) {
    return SalesSummary(
      totalCount: orders.length,
      openCount: orders.where((o) => o.isOpen).length,
      completedCount: orders.where((o) => o.isCompleted).length,
      cancelledCount: orders.where((o) => o.isCancelled).length,
      returnedCount: orders.where((o) => o.isReturned).length,
    );
  }
}
