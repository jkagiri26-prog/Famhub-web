/// ============================================================
/// FINANCE REPOSITORY (INFRASTRUCTURE)
/// ============================================================
///
/// Delegates reads to the Finance remote data source and translates
/// PostgREST/auth failures into typed domain exceptions.
///
/// Error translation:
///   42501            -> FinanceDataException(isUnauthorized)
///   P0002/PGRST116   -> FinanceDataException(isNotFound)
///   22023            -> FinanceDataException(isInvalid)
///   55000            -> FinanceDataException(isLifecycleBlocked)
///   23505            -> FinanceDataException(isConflict)
///   missing relation -> FinanceUnavailableException
///
/// No raw SQL, function names, provider payloads, or database internals are
/// placed in user-facing messages.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data_sources/finance_remote_data_source.dart';
import '../../domain/models/finance_obligation_balance.dart';
import '../../domain/models/finance_payment.dart';
import '../../domain/models/finance_payment_attempt.dart';
import '../../domain/models/finance_settlement.dart';
import '../../domain/repositories/finance_repository.dart';

class FinanceRepositoryImpl implements FinanceRepository {
  FinanceRepositoryImpl({required FinanceRemoteDataSource dataSource})
    : _dataSource = dataSource;

  final FinanceRemoteDataSource _dataSource;

  @override
  Future<List<FinanceObligationBalance>> fetchObligationBalances() {
    return _guard(_dataSource.fetchObligationBalances);
  }

  @override
  Future<List<FinanceSettlement>> fetchSettlementHistory(String obligationId) {
    return _guard(() => _dataSource.fetchSettlementHistory(obligationId));
  }

  @override
  Future<List<FinancePayment>> fetchVerifiedPaymentCollections() {
    return _guard(_dataSource.fetchVerifiedPaymentCollections);
  }

  @override
  Future<FinancePaymentAttempt?> fetchPaymentAttemptStatus(
    String paymentAttemptId,
  ) {
    return _guard(
      () => _dataSource.fetchPaymentAttemptStatus(paymentAttemptId),
    );
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      if (_isMissingFinanceObject(e)) {
        throw const FinanceUnavailableException(
          'Finance data is not available in this environment yet.',
        );
      }
      throw FinanceDataException(_safeMessage(e.code), code: e.code);
    } on AuthException {
      throw const FinanceDataException(
        'Please sign in to view finance data.',
        code: '42501',
      );
    }
  }

  static bool _isMissingFinanceObject(PostgrestException e) {
    final code = e.code ?? '';
    if (code == 'PGRST202' ||
        code == 'PGRST205' ||
        code == 'PGRST106' ||
        code == '42P01' ||
        code == '42883') {
      return true;
    }
    final text = e.message.toLowerCase();
    return text.contains('could not find the function') ||
        text.contains('could not find the table') ||
        text.contains('does not exist') ||
        text.contains('schema must be one of');
  }

  static String _safeMessage(String? code) {
    return switch (code) {
      '42501' => 'You do not have permission to view this finance data.',
      'P0002' || 'PGRST116' => 'That finance record could not be found.',
      '22023' => 'The finance request is not valid.',
      '55000' => 'This finance record is not available in its current state.',
      '23505' => 'A matching finance record already exists.',
      _ => 'Finance data is not available right now.',
    };
  }
}
