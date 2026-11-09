/// ============================================================
/// FINANCE — SETTLEMENT HISTORY READ MODEL
/// ============================================================
///
/// Source: `finance.v_obligation_settlement_history`
/// (security_invoker view). Read-only and RLS-scoped to the caller's
/// obligation party membership.
///
/// The view deliberately exposes only:
///   id, obligation_id, payment_id, currency, amount, settled_at
/// It does not expose settlement metadata, journal ids, or idempotency keys.
/// ============================================================
library;

class FinanceSettlement {
  final String id;
  final String obligationId;
  final String paymentId;
  final String currency;
  final double amount;
  final DateTime settledAt;

  const FinanceSettlement({
    required this.id,
    required this.obligationId,
    required this.paymentId,
    required this.currency,
    required this.amount,
    required this.settledAt,
  });

  factory FinanceSettlement.fromMap(Map<String, dynamic> map) {
    return FinanceSettlement(
      id: _asString(map['id']),
      obligationId: _asString(map['obligation_id']),
      paymentId: _asString(map['payment_id']),
      currency: _asString(map['currency']),
      amount: _asDouble(map['amount']),
      settledAt: _asDateTime(map['settled_at']),
    );
  }
}

String _asString(Object? value) => value?.toString() ?? '';

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _asDateTime(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw FormatException('Invalid finance timestamp: $value');
  }
  return parsed;
}
