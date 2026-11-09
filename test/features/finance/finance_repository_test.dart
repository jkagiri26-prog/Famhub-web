import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/finance/domain/repositories/finance_repository.dart';
import 'package:famhub_app/features/finance/infrastructure/repositories/finance_repository_impl.dart';

import 'finance_test_harness.dart';

void main() {
  group('FinanceRepository success paths', () {
    test('returns obligation balances unchanged', () async {
      final dataSource = FakeFinanceRemoteDataSource()
        ..obligationBalances = [sampleObligationBalance];
      final repo = FinanceRepositoryImpl(dataSource: dataSource);

      final result = await repo.fetchObligationBalances();

      expect(result, [sampleObligationBalance]);
    });

    test('returns settlement history unchanged', () async {
      final dataSource = FakeFinanceRemoteDataSource()
        ..settlements = [sampleSettlement];
      final repo = FinanceRepositoryImpl(dataSource: dataSource);

      final result = await repo.fetchSettlementHistory('obligation-1');

      expect(result, [sampleSettlement]);
    });

    test('returns verified payment collections unchanged', () async {
      final dataSource = FakeFinanceRemoteDataSource()
        ..payments = [samplePayment];
      final repo = FinanceRepositoryImpl(dataSource: dataSource);

      final result = await repo.fetchVerifiedPaymentCollections();

      expect(result, [samplePayment]);
    });

    test('returns payment attempt status unchanged', () async {
      final dataSource = FakeFinanceRemoteDataSource()
        ..attemptStatus = samplePaymentAttempt;
      final repo = FinanceRepositoryImpl(dataSource: dataSource);

      final result = await repo.fetchPaymentAttemptStatus('attempt-1');

      expect(result, samplePaymentAttempt);
    });

    test('handles empty results without throwing', () async {
      final dataSource = FakeFinanceRemoteDataSource();
      final repo = FinanceRepositoryImpl(dataSource: dataSource);

      expect(await repo.fetchObligationBalances(), isEmpty);
      expect(await repo.fetchSettlementHistory('obligation-1'), isEmpty);
      expect(await repo.fetchVerifiedPaymentCollections(), isEmpty);
      expect(await repo.fetchPaymentAttemptStatus('attempt-1'), isNull);
    });
  });

  group('FinanceRepository SQLSTATE mapping', () {
    Future<FinanceDataException> capture(PostgrestException error) async {
      final dataSource = FakeFinanceRemoteDataSource()
        ..onObligationBalances = () async => throw error;
      final repo = FinanceRepositoryImpl(dataSource: dataSource);

      try {
        await repo.fetchObligationBalances();
      } on FinanceDataException catch (e) {
        return e;
      }
      fail('Expected FinanceDataException');
    }

    test('42501 maps to unauthorized', () async {
      final error = await capture(
        const PostgrestException(message: 'permission denied', code: '42501'),
      );

      expect(error.isUnauthorized, isTrue);
      expect(error.code, '42501');
      expect(
        error.message,
        'You do not have permission to view this finance data.',
      );
    });

    test('P0002 and PGRST116 map to not found', () async {
      final p0002 = await capture(
        const PostgrestException(message: 'missing', code: 'P0002'),
      );
      final pgrst116 = await capture(
        const PostgrestException(message: 'no rows', code: 'PGRST116'),
      );

      expect(p0002.isNotFound, isTrue);
      expect(pgrst116.isNotFound, isTrue);
      expect(p0002.message, 'That finance record could not be found.');
    });

    test('22023 maps to invalid', () async {
      final error = await capture(
        const PostgrestException(message: 'invalid input', code: '22023'),
      );

      expect(error.isInvalid, isTrue);
      expect(error.message, 'The finance request is not valid.');
    });

    test('55000 maps to lifecycle blocked', () async {
      final error = await capture(
        const PostgrestException(message: 'bad state', code: '55000'),
      );

      expect(error.isLifecycleBlocked, isTrue);
      expect(
        error.message,
        'This finance record is not available in its current state.',
      );
    });

    test('23505 maps to conflict', () async {
      final error = await capture(
        const PostgrestException(message: 'duplicate', code: '23505'),
      );

      expect(error.isConflict, isTrue);
      expect(error.message, 'A matching finance record already exists.');
    });

    test('unknown codes use a safe generic message', () async {
      final error = await capture(
        const PostgrestException(
          message: 'internal relation finance.secret_table failed',
          code: 'XX000',
        ),
      );

      expect(error.code, 'XX000');
      expect(error.message, 'Finance data is not available right now.');
      expect(error.message, isNot(contains('secret_table')));
      expect(error.message, isNot(contains('finance.')));
    });
  });

  group('FinanceRepository unavailable mappings', () {
    for (final code in const [
      'PGRST202',
      'PGRST205',
      'PGRST106',
      '42P01',
      '42883',
    ]) {
      test('$code maps to FinanceUnavailableException', () async {
        final dataSource = FakeFinanceRemoteDataSource()
          ..onObligationBalances = () async => throw PostgrestException(
            message: 'could not find the function',
            code: code,
          );
        final repo = FinanceRepositoryImpl(dataSource: dataSource);

        await expectLater(
          repo.fetchObligationBalances(),
          throwsA(isA<FinanceUnavailableException>()),
        );
      });
    }

    test('missing-object message without a code is unavailable', () async {
      final dataSource = FakeFinanceRemoteDataSource()
        ..onVerifiedPayments = () async => throw const PostgrestException(
          message: 'relation "v_verified_payment_collections" does not exist',
        );
      final repo = FinanceRepositoryImpl(dataSource: dataSource);

      await expectLater(
        repo.fetchVerifiedPaymentCollections(),
        throwsA(isA<FinanceUnavailableException>()),
      );
    });
  });

  group('FinanceRepository auth handling', () {
    test(
      'AuthException maps to unauthorized without leaking details',
      () async {
        final dataSource = FakeFinanceRemoteDataSource()
          ..onPaymentAttemptStatus = (_) async =>
              throw const AuthException('JWT expired', code: 'session_expired');
        final repo = FinanceRepositoryImpl(dataSource: dataSource);

        try {
          await repo.fetchPaymentAttemptStatus('attempt-1');
          fail('Expected FinanceDataException');
        } on FinanceDataException catch (e) {
          expect(e.isUnauthorized, isTrue);
          expect(e.message, 'Please sign in to view finance data.');
          expect(e.message, isNot(contains('JWT')));
        }
      },
    );
  });
}
