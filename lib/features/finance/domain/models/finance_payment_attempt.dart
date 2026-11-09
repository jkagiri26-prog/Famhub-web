/// ============================================================
/// FINANCE — PAYMENT ATTEMPT STATUS READ MODEL
/// ============================================================
///
/// Source: `finance.get_payment_attempt_status(p_payment_attempt_id uuid)`
/// (SECURITY DEFINER, authenticated EXECUTE).
///
/// The function returns only:
///   payment_attempt_id, obligation_id, status, amount, currency,
///   created_at, updated_at, completed_at, failure_state
///
/// `failure_state` is the safe derived value ('failed' or null). Raw failure
/// codes/messages, provider request references, payloads, metadata and
/// idempotency keys are never exposed.
/// ============================================================
library;

/// `finance.payment_attempts.status`
enum FinancePaymentAttemptStatus {
  created('created'),
  pending('pending'),
  processing('processing'),
  succeeded('succeeded'),
  failed('failed'),
  cancelled('cancelled'),
  expired('expired');

  const FinancePaymentAttemptStatus(this.dbValue);

  final String dbValue;

  static FinancePaymentAttemptStatus fromDb(String? value) {
    for (final status in values) {
      if (status.dbValue == value) return status;
    }
    return FinancePaymentAttemptStatus.created;
  }
}

class FinancePaymentAttempt {
  final String paymentAttemptId;
  final String obligationId;
  final FinancePaymentAttemptStatus status;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? failureState;

  const FinancePaymentAttempt({
    required this.paymentAttemptId,
    required this.obligationId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.failureState,
  });

  factory FinancePaymentAttempt.fromMap(Map<String, dynamic> map) {
    return FinancePaymentAttempt(
      paymentAttemptId: _asString(map['payment_attempt_id']),
      obligationId: _asString(map['obligation_id']),
      status: FinancePaymentAttemptStatus.fromDb(map['status']?.toString()),
      amount: _asDouble(map['amount']),
      currency: _asString(map['currency']),
      createdAt: _asDateTime(map['created_at']),
      updatedAt: _asDateTime(map['updated_at']),
      completedAt: _asDateTimeOrNull(map['completed_at']),
      failureState: _asNullableString(map['failure_state']),
    );
  }

  bool get isTerminal =>
      status == FinancePaymentAttemptStatus.succeeded ||
      status == FinancePaymentAttemptStatus.failed ||
      status == FinancePaymentAttemptStatus.cancelled ||
      status == FinancePaymentAttemptStatus.expired;

  bool get hasFailed => failureState == 'failed';
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
