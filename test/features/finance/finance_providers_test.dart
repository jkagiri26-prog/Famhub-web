import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/features/finance/application/providers/finance_read_providers.dart';
import 'package:famhub_app/features/finance/application/providers/finance_repository_provider.dart';
import 'package:famhub_app/features/finance/domain/models/finance_obligation_balance.dart';
import 'package:famhub_app/features/finance/domain/repositories/finance_repository.dart';

import 'finance_test_harness.dart';

void main() {
  ProviderContainer makeContainer(
    FakeFinanceRepository repository, {
    EntityContext context = signedInContext,
  }) {
    final container = ProviderContainer(
      // Disable Riverpod 3 automatic retries so error states surface immediately.
      retry: (retryCount, error) => null,
      overrides: [
        financeRepositoryProvider.overrideWithValue(repository),
        contextOverride(context: context),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Obligation balance provider', () {
    test('loads data for an authenticated context', () async {
      final repository = FakeFinanceRepository(
        obligationBalances: [sampleObligationBalance],
      );
      final container = makeContainer(repository);

      final result = await container.read(
        financeObligationBalancesProvider.future,
      );

      expect(result, [sampleObligationBalance]);
      expect(repository.obligationBalanceCalls, 1);
    });

    test('exposes loading before completion', () async {
      final completer = Completer<List<FinanceObligationBalance>>();
      final repository = FakeFinanceRepository()
        ..onObligationBalances = () => completer.future;
      final container = makeContainer(repository);

      expect(
        container.read(financeObligationBalancesProvider),
        isA<AsyncLoading<List<FinanceObligationBalance>>>(),
      );

      completer.complete([sampleObligationBalance]);
      final result = await container.read(
        financeObligationBalancesProvider.future,
      );

      expect(result, [sampleObligationBalance]);
    });

    test('surfaces failures as AsyncError', () async {
      const failure = FinanceDataException(
        'Finance data is not available right now.',
        code: 'XX000',
      );
      final repository = FakeFinanceRepository()
        ..onObligationBalances = () async => throw failure;
      final container = makeContainer(repository);

      await expectLater(
        container.read(financeObligationBalancesProvider.future),
        throwsA(same(failure)),
      );
      expect(
        container.read(financeObligationBalancesProvider),
        isA<AsyncError<List<FinanceObligationBalance>>>(),
      );
    });

    test(
      'guest context returns empty without calling the repository',
      () async {
        final repository = FakeFinanceRepository()
          ..onObligationBalances = () async {
            fail('Repository must not be called for a guest');
          };
        final container = makeContainer(repository, context: guestContext);

        final result = await container.read(
          financeObligationBalancesProvider.future,
        );

        expect(result, isEmpty);
        expect(repository.obligationBalanceCalls, 0);
      },
    );
  });

  group('Settlement history provider', () {
    test('loads data for one obligation', () async {
      final repository = FakeFinanceRepository(settlements: [sampleSettlement]);
      final container = makeContainer(repository);

      final result = await container.read(
        financeSettlementHistoryProvider('obligation-1').future,
      );

      expect(result, [sampleSettlement]);
      expect(repository.settlementHistoryCalls, 1);
      expect(repository.lastSettlementObligationId, 'obligation-1');
    });

    test('empty obligation id short-circuits', () async {
      final repository = FakeFinanceRepository()
        ..onSettlementHistory = (_) async {
          fail('Repository must not be called for an empty id');
        };
      final container = makeContainer(repository);

      final result = await container.read(
        financeSettlementHistoryProvider('').future,
      );

      expect(result, isEmpty);
      expect(repository.settlementHistoryCalls, 0);
    });

    test(
      'guest context returns empty without calling the repository',
      () async {
        final repository = FakeFinanceRepository()
          ..onSettlementHistory = (_) async {
            fail('Repository must not be called for a guest');
          };
        final container = makeContainer(repository, context: guestContext);

        final result = await container.read(
          financeSettlementHistoryProvider('obligation-1').future,
        );

        expect(result, isEmpty);
        expect(repository.settlementHistoryCalls, 0);
      },
    );
  });

  group('Verified collections provider', () {
    test('loads verified payment collections', () async {
      final repository = FakeFinanceRepository(payments: [samplePayment]);
      final container = makeContainer(repository);

      final result = await container.read(
        financeVerifiedPaymentCollectionsProvider.future,
      );

      expect(result, [samplePayment]);
      expect(repository.verifiedPaymentCalls, 1);
    });

    test(
      'guest context returns empty without calling the repository',
      () async {
        final repository = FakeFinanceRepository()
          ..onVerifiedPayments = () async {
            fail('Repository must not be called for a guest');
          };
        final container = makeContainer(repository, context: guestContext);

        final result = await container.read(
          financeVerifiedPaymentCollectionsProvider.future,
        );

        expect(result, isEmpty);
        expect(repository.verifiedPaymentCalls, 0);
      },
    );
  });

  group('Payment attempt status provider', () {
    test('loads the safe status for one attempt', () async {
      final repository = FakeFinanceRepository(
        attemptStatus: samplePaymentAttempt,
      );
      final container = makeContainer(repository);

      final result = await container.read(
        financePaymentAttemptStatusProvider('attempt-1').future,
      );

      expect(result, samplePaymentAttempt);
      expect(repository.paymentAttemptStatusCalls, 1);
      expect(repository.lastPaymentAttemptId, 'attempt-1');
    });

    test('returns null when the status function has no row', () async {
      final repository = FakeFinanceRepository();
      final container = makeContainer(repository);

      final result = await container.read(
        financePaymentAttemptStatusProvider('attempt-missing').future,
      );

      expect(result, isNull);
      expect(repository.paymentAttemptStatusCalls, 1);
    });

    test('empty attempt id short-circuits', () async {
      final repository = FakeFinanceRepository()
        ..onPaymentAttemptStatus = (_) async {
          fail('Repository must not be called for an empty id');
        };
      final container = makeContainer(repository);

      final result = await container.read(
        financePaymentAttemptStatusProvider('').future,
      );

      expect(result, isNull);
      expect(repository.paymentAttemptStatusCalls, 0);
    });

    test('guest context returns null without calling the repository', () async {
      final repository = FakeFinanceRepository()
        ..onPaymentAttemptStatus = (_) async {
          fail('Repository must not be called for a guest');
        };
      final container = makeContainer(repository, context: guestContext);

      final result = await container.read(
        financePaymentAttemptStatusProvider('attempt-1').future,
      );

      expect(result, isNull);
      expect(repository.paymentAttemptStatusCalls, 0);
    });
  });
}
