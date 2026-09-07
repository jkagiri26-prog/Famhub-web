/// ============================================================
/// BUSINESS TRANSACTION (DOMAIN)
/// ============================================================
///
/// Read model for ONE row of `commerce.transactions` — the canonical,
/// currency-aware payment transaction table for the business's seller
/// profile(s).
///
/// Actual documented columns (docs/Backend schemas/commerce schema.md):
///   id, order_id (→ commerce.orders), supplier_id
///   (→ commerce.business_profiles = the business of record), amount,
///   currency, payment_method, payment_status, transaction_id,
///   transaction_date, created_at, updated_at, recorded_by, profile_id
///
/// Payment status enum (backend CHECK):
///   pending | completed | failed | refunded
/// Payment method enum:
///   mpesa | visa | card | bank
/// recorded_by enum:
///   supplier | buyer | system
///
/// Amount is always shown with its real backend currency code — no
/// currency symbol is ever invented and amounts are never summed.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class BusinessTransaction {
  /// commerce.transactions.id
  final String id;

  /// FK → commerce.orders.
  final String orderId;

  /// FK → commerce.business_profiles (business of record).
  final String supplierId;

  final double amount;

  /// Real backend currency code (default 'KES').
  final String currency;

  /// Raw payment method: mpesa | visa | card | bank.
  final String paymentMethod;

  /// Raw payment status: pending | completed | failed | refunded.
  final String paymentStatus;

  /// External/provider transaction reference (nullable text).
  final String? transactionRef;

  final DateTime? transactionDate;

  /// Raw recorded_by: supplier | buyer | system.
  final String? recordedBy;

  const BusinessTransaction({
    required this.id,
    required this.orderId,
    required this.supplierId,
    this.amount = 0,
    this.currency = 'KES',
    this.paymentMethod = 'mpesa',
    this.paymentStatus = 'pending',
    this.transactionRef,
    this.transactionDate,
    this.recordedBy,
  });

  bool get isCompleted => paymentStatus == 'completed';

  bool get isPending => paymentStatus == 'pending';

  bool get isFailed => paymentStatus == 'failed';

  bool get isRefunded => paymentStatus == 'refunded';
}
