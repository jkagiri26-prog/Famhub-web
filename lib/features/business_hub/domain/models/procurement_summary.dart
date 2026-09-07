/// ============================================================
/// PROCUREMENT SUMMARY (DOMAIN MODEL)
/// ============================================================
///
/// Compact aggregate derived from the active business's purchase-order
/// list. Display-only counts computed client-side from canonical
/// `commerce.purchase_orders` rows.
///
/// Only counts derivable from the documented status enum are produced —
/// no invented financial KPIs.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import '../entities/purchase_order.dart';

class ProcurementSummary {
  /// Total number of purchase orders.
  final int totalCount;

  /// Open orders: status pending or sent.
  final int openCount;

  /// Received (completed) orders.
  final int completedCount;

  /// Cancelled orders.
  final int cancelledCount;

  const ProcurementSummary({
    required this.totalCount,
    required this.openCount,
    required this.completedCount,
    required this.cancelledCount,
  });

  factory ProcurementSummary.from(List<PurchaseOrder> orders) {
    return ProcurementSummary(
      totalCount: orders.length,
      openCount: orders.where((o) => o.isOpen).length,
      completedCount: orders.where((o) => o.isReceived).length,
      cancelledCount: orders.where((o) => o.isCancelled).length,
    );
  }
}
