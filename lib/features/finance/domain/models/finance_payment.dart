/// ============================================================
/// FINANCE — VERIFIED PAYMENT COLLECTION READ MODEL
/// ============================================================
///
/// Source: `finance.v_verified_payment_collections`
/// (security_invoker view). Read-only.
///
/// The view is the approved customer-facing payment surface. It never
/// includes `finance.payments.verification_metadata`, payer/payee private
/// profile ids beyond the entity ids required for party display, or raw
/// provider payloads.
/// ============================================================
library;

class FinancePayment {
  final String paymentId;
  final String provider;
  final String? providerReference;
  final double amount;
  final String currency;
  final String payerEntityId;
  final String payeeEntityId;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final String? collectionRecordStatus;
  final String? bankSettlementStatus;

  const FinancePayment({
    required this.paymentId,
    required this.provider,
    this.providerReference,
    required this.amount,
    required this.currency,
    required this.payerEntityId,
    required this.payeeEntityId,
    this.verifiedAt,
    required this.createdAt,
    this.collectionRecordStatus,
    this.bankSettlementStatus,
  });

  factory FinancePayment.fromMap(Map<String, dynamic> map) {
    return FinancePayment(
      paymentId: _asString(map['payment_id']),
      provider: _asString(map['provider']),
      providerReference: _asNullableString(map['provider_reference']),
      amount: _asDouble(map['amount']),
      currency: _asString(map['currency']),
      payerEntityId: _asString(map['payer_entity_id']),
      payeeEntityId: _asString(map['payee_entity_id']),
      verifiedAt: _asDateTimeOrNull(map['verified_at']),
      createdAt: _asDateTime(map['created_at']),
      collectionRecordStatus: _asNullableString(
        map['collection_record_status'],
      ),
      bankSettlementStatus: _asNullableString(map['bank_settlement_status']),
    );
  }

  bool get isVerified => verifiedAt != null;
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
