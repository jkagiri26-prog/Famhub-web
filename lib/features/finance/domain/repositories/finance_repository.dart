/// ============================================================
/// FINANCE REPOSITORY (DOMAIN CONTRACT)
/// ============================================================
///
/// Read-only Finance contract for the current phase. All authorization is
/// enforced by the authenticated Supabase session and database RLS /
/// SECURITY DEFINER functions; this layer never sends user or profile ids as
/// ownership claims.
/// ============================================================
library;

import '../models/finance_obligation_balance.dart';
import '../models/finance_payment.dart';
import '../models/finance_payment_attempt.dart';
import '../models/finance_settlement.dart';

/// Thrown when the deployed Finance view/function is not present or not
/// exposed through PostgREST. This is a deployment fact, not a user error.
class FinanceUnavailableException implements Exception {
  const FinanceUnavailableException([this.reason]);

  final String? reason;

  @override
  String toString() => reason ?? 'Finance data is not available yet.';
}

/// Thrown when Finance data cannot be read. [code] carries the backend
/// SQLSTATE/PostgREST code for branching; no SQL or database internals are
/// exposed through this exception.
class FinanceDataException implements Exception {
  const FinanceDataException(this.message, {this.code});

  final String message;
  final String? code;

  bool get isUnauthorized => code == '42501';

  bool get isNotFound => code == 'P0002' || code == 'PGRST116';

  bool get isInvalid => code == '22023';

  bool get isConflict => code == '23505';

  bool get isLifecycleBlocked => code == '55000';

  @override
  String toString() => message;
}

abstract class FinanceRepository {
  /// Read `finance.v_obligation_balances`.
  Future<List<FinanceObligationBalance>> fetchObligationBalances();

  /// Read `finance.v_obligation_settlement_history` for one obligation.
  Future<List<FinanceSettlement>> fetchSettlementHistory(String obligationId);

  /// Read `finance.v_verified_payment_collections`.
  Future<List<FinancePayment>> fetchVerifiedPaymentCollections();

  /// Read `finance.get_payment_attempt_status(p_payment_attempt_id)`.
  ///
  /// Returns null when the function returns no row: unknown attempt id,
  /// not the caller's attempt, or no active payer-entity membership. The
  /// function itself is the authorization boundary.
  Future<FinancePaymentAttempt?> fetchPaymentAttemptStatus(
    String paymentAttemptId,
  );
}
