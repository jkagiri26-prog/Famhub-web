/// ============================================================
/// FINANCE REMOTE DATA SOURCE
/// ============================================================
///
/// Read-only Supabase access for Finance. Uses the canonical authenticated
/// client and explicit column lists only.
///
/// Security boundaries:
///   - no `select('*')`
///   - no direct reads of `finance.obligation_settlements`
///   - no direct reads of `finance.payment_attempts`
///   - no provider payloads, metadata, idempotency keys, verification
///     metadata, or raw failure messages
///   - no service-role client
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/finance_obligation_balance.dart';
import '../../domain/models/finance_payment.dart';
import '../../domain/models/finance_payment_attempt.dart';
import '../../domain/models/finance_settlement.dart';

/// Explicit column contracts for the Finance read surfaces.
abstract final class FinanceColumns {
  static const String obligationBalance = '''
    obligation_id, payer_entity_id, payee_entity_id, commercial_order_id,
    legacy_order_id, obligation_type, obligation_status, currency,
    obligation_amount, total_settlements, outstanding_balance,
    settlement_count, due_at, created_at, updated_at
  ''';

  static const String settlementHistory = '''
    id, obligation_id, payment_id, currency, amount, settled_at
  ''';

  static const String verifiedPayment = '''
    payment_id, provider, provider_reference, amount, currency,
    payer_entity_id, payee_entity_id, verified_at, created_at,
    collection_record_status, bank_settlement_status
  ''';
}

/// Literal Finance RPC and parameter names from the deployed contract.
abstract final class FinanceRpcNames {
  static const String getPaymentAttemptStatus = 'get_payment_attempt_status';
}

abstract final class FinanceRpcParams {
  static const String paymentAttemptId = 'p_payment_attempt_id';
}

class FinanceRemoteDataSource {
  FinanceRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<FinanceObligationBalance>> fetchObligationBalances() async {
    final response = await _client
        .schema('finance')
        .from('v_obligation_balances')
        .select(FinanceColumns.obligationBalance)
        .order('created_at', ascending: false);

    return (response as List)
        .whereType<Map>()
        .map(
          (row) =>
              FinanceObligationBalance.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<List<FinanceSettlement>> fetchSettlementHistory(
    String obligationId,
  ) async {
    if (obligationId.isEmpty) return const [];

    final response = await _client
        .schema('finance')
        .from('v_obligation_settlement_history')
        .select(FinanceColumns.settlementHistory)
        .eq('obligation_id', obligationId)
        .order('settled_at', ascending: true);

    return (response as List)
        .whereType<Map>()
        .map((row) => FinanceSettlement.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<List<FinancePayment>> fetchVerifiedPaymentCollections() async {
    final response = await _client
        .schema('finance')
        .from('v_verified_payment_collections')
        .select(FinanceColumns.verifiedPayment)
        .order('verified_at', ascending: false);

    return (response as List)
        .whereType<Map>()
        .map((row) => FinancePayment.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<FinancePaymentAttempt?> fetchPaymentAttemptStatus(
    String paymentAttemptId,
  ) async {
    if (paymentAttemptId.isEmpty) return null;

    final response = await _client
        .schema('finance')
        .rpc(
          FinanceRpcNames.getPaymentAttemptStatus,
          params: {FinanceRpcParams.paymentAttemptId: paymentAttemptId},
        );

    final row = _firstRow(response);
    if (row == null) return null;
    return FinancePaymentAttempt.fromMap(row);
  }

  static Map<String, dynamic>? _firstRow(Object? response) {
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List) {
      for (final item in response) {
        if (item is Map) return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }
}
