/// ============================================================
/// PURCHASE ORDER (DOMAIN)
/// ============================================================
///
/// Read model for ONE row of `commerce.purchase_orders` — the canonical
/// procurement table.
///
/// Actual documented columns (docs/Backend schemas/commerce schema.md):
///   id, supplier_id (→ commerce.business_profiles), created_by
///   (→ users.profiles), status, total_amount, currency, notes,
///   created_at
///
/// There is NO buyer/business entity column on this table. Entity
/// scoping is achieved by resolving the active business's people scope
/// (owner + `core.entity_members`) and reading purchase orders where
/// `created_by` belongs to that scope. No client-supplied user ownership
/// id is ever sent.
///
/// Status enum (backend CHECK): pending | sent | received | cancelled.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class PurchaseOrder {
  /// commerce.purchase_orders.id
  final String id;

  /// FK → commerce.business_profiles (the supplier of record).
  final String? supplierId;

  /// Resolved supplier display name (business_profiles.supplier_name).
  final String? supplierName;

  /// FK → users.profiles (the person who created the PO).
  final String? createdBy;

  /// Raw status: pending | sent | received | cancelled.
  final String status;

  /// Total order value (numeric, default 0).
  final double totalAmount;

  /// Currency (text, default KES).
  final String currency;

  final String? notes;

  final DateTime? createdAt;

  const PurchaseOrder({
    required this.id,
    this.supplierId,
    this.supplierName,
    this.createdBy,
    this.status = 'pending',
    this.totalAmount = 0,
    this.currency = 'KES',
    this.notes,
    this.createdAt,
  });

  /// Open (not yet completed/cancelled): pending or sent.
  bool get isOpen => status == 'pending' || status == 'sent';

  /// Completed/received.
  bool get isReceived => status == 'received';

  bool get isCancelled => status == 'cancelled';

  bool get hasValue => totalAmount > 0;

  /// Supplier fallback for display.
  String get displaySupplier =>
      (supplierName != null && supplierName!.trim().isNotEmpty)
          ? supplierName!.trim()
          : (supplierId != null ? 'Supplier' : 'Supplier not linked');
}
