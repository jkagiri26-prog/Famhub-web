/// ============================================================
/// PAYMENTS SUMMARY (DOMAIN MODEL)
/// ============================================================
///
/// Compact aggregate derived from the active business's payment
/// transactions. Display-only COUNTS computed from canonical
/// `commerce.transactions` rows using the real payment status enum.
///
/// No amounts are summed: totals/revenue would require reliable
/// currency-consistent aggregation, which is out of scope for this
/// read-only visibility surface.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import '../entities/business_transaction.dart';

class PaymentsSummary {
  final int totalCount;
  final int completedCount;
  final int pendingCount;
  final int failedCount;
  final int refundedCount;

  const PaymentsSummary({
    required this.totalCount,
    required this.completedCount,
    required this.pendingCount,
    required this.failedCount,
    required this.refundedCount,
  });

  factory PaymentsSummary.from(List<BusinessTransaction> transactions) {
    int countOf(bool Function(BusinessTransaction) test) =>
        transactions.where(test).length;
    return PaymentsSummary(
      totalCount: transactions.length,
      completedCount: countOf((t) => t.isCompleted),
      pendingCount: countOf((t) => t.isPending),
      failedCount: countOf((t) => t.isFailed),
      refundedCount: countOf((t) => t.isRefunded),
    );
  }
}
