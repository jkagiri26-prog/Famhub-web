/// ============================================================
/// SALES ORDER (DOMAIN)
/// ============================================================
///
/// Read model for ONE row of `commerce.orders` — the canonical
/// marketplace order/sales table.
///
/// Actual documented columns (docs/Backend schemas/commerce schema.md):
///   id, buyer_id (→ users.profiles), listing_id (→ marketplace.listings),
///   supplier_id (→ commerce.business_profiles = the SELLER business of
///   record), quantity, total_amount, status, payment_status, order_date,
///   delivery_date, created_at, updated_at, payment_mode, unit_id,
///   entity_id, business_profile_id
///
/// Status enum (backend CHECK):
///   pending | confirmed | shipped | delivered | cancelled | returned
/// Payment status enum:
///   pending | completed | failed | refunded
///
/// NOTE: orders has NO currency column — amounts are shown without an
/// assumed currency symbol.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class SalesOrder {
  /// commerce.orders.id
  final String id;

  /// FK → users.profiles (buyer).
  final String buyerId;

  /// Resolved buyer display name (users.profiles first/last name).
  final String? buyerName;

  /// FK → marketplace.listings.
  final String? listingId;

  /// FK → commerce.business_profiles (seller business of record).
  final String? supplierId;

  /// Header quantity.
  final double quantity;

  /// Order total amount (no currency column exists on this table).
  final double totalAmount;

  /// Raw status: pending | confirmed | shipped | delivered | cancelled |
  /// returned.
  final String status;

  /// Raw payment status: pending | completed | failed | refunded.
  final String paymentStatus;

  /// Raw payment mode: direct_supplier | platform | escrow.
  final String? paymentMode;

  final DateTime? orderDate;
  final DateTime? deliveryDate;

  const SalesOrder({
    required this.id,
    required this.buyerId,
    this.buyerName,
    this.listingId,
    this.supplierId,
    this.quantity = 0,
    this.totalAmount = 0,
    this.status = 'pending',
    this.paymentStatus = 'pending',
    this.paymentMode,
    this.orderDate,
    this.deliveryDate,
  });

  /// Open / in-progress: pending, confirmed or shipped.
  bool get isOpen =>
      status == 'pending' || status == 'confirmed' || status == 'shipped';

  bool get isCompleted => status == 'delivered';

  bool get isCancelled => status == 'cancelled';

  bool get isReturned => status == 'returned';

  bool get isPaid => paymentStatus == 'completed';

  /// Buyer fallback for display.
  String get displayBuyer =>
      (buyerName != null && buyerName!.trim().isNotEmpty)
          ? buyerName!.trim()
          : 'Buyer';
}
