/// ============================================================
/// FINANCE — OBLIGATION BALANCE READ MODEL
/// ============================================================
///
/// Source: `finance.v_obligation_balances` (security_invoker view).
/// Read-only. The view is RLS-scoped to the authenticated caller's
/// obligations; no entity or profile id is used as an authorization claim.
/// ============================================================
library;

/// `finance.obligations.obligation_type`
enum FinanceObligationType {
  order('order'),
  subscription('subscription'),
  fee('fee'),
  payout('payout'),
  refund('refund'),
  other('other');

  const FinanceObligationType(this.dbValue);

  final String dbValue;

  static FinanceObligationType fromDb(String? value) {
    for (final type in values) {
      if (type.dbValue == value) return type;
    }
    return FinanceObligationType.other;
  }
}

/// `finance.obligations.status`
enum FinanceObligationStatus {
  draft('draft'),
  open('open'),
  partiallySettled('partially_settled'),
  settled('settled'),
  cancelled('cancelled'),
  voided('void');

  const FinanceObligationStatus(this.dbValue);

  final String dbValue;

  static FinanceObligationStatus fromDb(String? value) {
    for (final status in values) {
      if (status.dbValue == value) return status;
    }
    return FinanceObligationStatus.draft;
  }
}

/// One row of `finance.v_obligation_balances`.
class FinanceObligationBalance {
  final String obligationId;
  final String payerEntityId;
  final String payeeEntityId;
  final String? commercialOrderId;
  final String? legacyOrderId;
  final FinanceObligationType obligationType;
  final FinanceObligationStatus status;
  final String currency;
  final double obligationAmount;
  final double totalSettlements;
  final double outstandingBalance;
  final int settlementCount;
  final DateTime? dueAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinanceObligationBalance({
    required this.obligationId,
    required this.payerEntityId,
    required this.payeeEntityId,
    this.commercialOrderId,
    this.legacyOrderId,
    required this.obligationType,
    required this.status,
    required this.currency,
    required this.obligationAmount,
    required this.totalSettlements,
    required this.outstandingBalance,
    required this.settlementCount,
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FinanceObligationBalance.fromMap(Map<String, dynamic> map) {
    return FinanceObligationBalance(
      obligationId: _asString(map['obligation_id']),
      payerEntityId: _asString(map['payer_entity_id']),
      payeeEntityId: _asString(map['payee_entity_id']),
      commercialOrderId: _asNullableString(map['commercial_order_id']),
      legacyOrderId: _asNullableString(map['legacy_order_id']),
      obligationType: FinanceObligationType.fromDb(
        map['obligation_type']?.toString(),
      ),
      status: FinanceObligationStatus.fromDb(
        map['obligation_status']?.toString(),
      ),
      currency: _asString(map['currency']),
      obligationAmount: _asDouble(map['obligation_amount']),
      totalSettlements: _asDouble(map['total_settlements']),
      outstandingBalance: _asDouble(map['outstanding_balance']),
      settlementCount: _asInt(map['settlement_count']),
      dueAt: _asDateTimeOrNull(map['due_at']),
      createdAt: _asDateTime(map['created_at']),
      updatedAt: _asDateTime(map['updated_at']),
    );
  }

  bool get isSettled => status == FinanceObligationStatus.settled;

  bool get hasOutstandingBalance => outstandingBalance > 0;
}

String _asString(Object? value) => value?.toString() ?? '';

String? _asNullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _asDateTime(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Invalid finance timestamp: $value');
  }
  return parsed;
}

DateTime? _asDateTimeOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
