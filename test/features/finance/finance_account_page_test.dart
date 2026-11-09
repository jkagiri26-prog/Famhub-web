import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/router/dynamic_route_registrar.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/router/route_names.dart';
import 'package:famhub_app/features/finance/application/providers/finance_repository_provider.dart';
import 'package:famhub_app/features/finance/domain/models/finance_obligation_balance.dart';
import 'package:famhub_app/features/finance/domain/models/finance_payment.dart';
import 'package:famhub_app/features/finance/presentation/pages/finance_account_page.dart';
import 'package:famhub_app/features/finance/presentation/widgets/finance_obligation_card.dart';

import 'finance_test_harness.dart';

FinanceObligationBalance _payeeObligation() {
  return FinanceObligationBalance(
    obligationId: 'obligation-2',
    payerEntityId: 'entity-2',
    payeeEntityId: 'entity-1',
    obligationType: FinanceObligationType.order,
    status: FinanceObligationStatus.open,
    currency: 'KES',
    obligationAmount: 2200,
    totalSettlements: 0,
    outstandingBalance: 2200,
    settlementCount: 0,
    createdAt: DateTime.utc(2026, 11, 9),
    updatedAt: DateTime.utc(2026, 11, 9),
  );
}

FinancePayment _payeePayment() {
  return FinancePayment(
    paymentId: 'payment-2',
    provider: 'bank',
    providerReference: 'BANK-9',
    amount: 2200,
    currency: 'KES',
    payerEntityId: 'entity-2',
    payeeEntityId: 'entity-1',
    verifiedAt: DateTime.utc(2026, 11, 9, 3),
    createdAt: DateTime.utc(2026, 11, 9, 2),
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  FakeFinanceRepository repository, {
  EntityContext context = signedInContext,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeRepositoryProvider.overrideWithValue(repository),
        contextOverride(context: context),
      ],
      child: const MaterialApp(home: Scaffold(body: FinanceAccountPage())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('finance account route is registered while finance is enabled', () {
    ModulePageRegistry.clear();
    bootstrapModulePageBuilders();
    addTearDown(ModulePageRegistry.clear);

    final router = DynamicRouteRegistrar.buildRouter([
      const RuntimeModule(
        moduleId: 'finance',
        displayName: 'Finance',
        route: AppRoutes.finance,
        isEnabled: true,
      ),
    ]);

    final match = router.configuration.findMatch(
      Uri.parse(AppRoutes.financeAccount),
    );

    expect(match.error, isNull);
    expect(match.matches, isNotEmpty);
  });

  testWidgets('shows payer and payee obligations and payments', (tester) async {
    final repository = FakeFinanceRepository(
      obligationBalances: [sampleObligationBalance, _payeeObligation()],
      payments: [samplePayment, _payeePayment()],
      settlements: [sampleSettlement],
    );

    await _pumpPage(tester, repository);

    expect(find.text('My Finance'), findsOneWidget);
    expect(find.text('Open obligations'), findsOneWidget);
    expect(find.text('Verified payments'), findsOneWidget);

    // Payer-side and payee-side rows must both remain visible.
    expect(find.text('You owe'), findsOneWidget);
    expect(find.text('Owed to you'), findsOneWidget);
    expect(find.text('Fee'), findsOneWidget);
    expect(find.text('Order obligation'), findsOneWidget);

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();

    expect(find.text('M-Pesa'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('SFC123'), findsOneWidget);
    expect(find.text('BANK-9'), findsOneWidget);
  });

  testWidgets('opens settlement history for a selected obligation', (
    tester,
  ) async {
    final repository = FakeFinanceRepository(
      obligationBalances: [sampleObligationBalance],
      settlements: [sampleSettlement],
    );

    await _pumpPage(tester, repository);

    await tester.tap(find.byType(FinanceObligationCard).first);
    await tester.pumpAndSettle();

    expect(find.text('Settlement history'), findsOneWidget);
    expect(find.text('KES 500.00'), findsOneWidget);
    expect(find.text('Payment payment-'), findsOneWidget);
  });

  testWidgets('checks payment attempt status by id', (tester) async {
    final repository = FakeFinanceRepository(
      obligationBalances: [sampleObligationBalance],
      attemptStatus: samplePaymentAttempt,
    );

    await _pumpPage(tester, repository);

    await tester.tap(find.text('Attempt status'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'attempt-1');
    await tester.tap(find.text('Check status'));
    await tester.pumpAndSettle();

    expect(find.text('KES 500.00'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Attempt failed'), findsOneWidget);
    expect(repository.lastPaymentAttemptId, 'attempt-1');
  });

  testWidgets('guest session is locked and does not query Finance data', (
    tester,
  ) async {
    final repository = FakeFinanceRepository()
      ..onObligationBalances = () async {
        fail('Repository must not be called for a guest');
      }
      ..onVerifiedPayments = () async {
        fail('Repository must not be called for a guest');
      };

    await _pumpPage(tester, repository, context: guestContext);

    expect(find.text('Finance locked'), findsOneWidget);
    expect(repository.obligationBalanceCalls, 0);
    expect(repository.verifiedPaymentCalls, 0);
  });

  testWidgets('empty Finance account shows empty states', (tester) async {
    final repository = FakeFinanceRepository();

    await _pumpPage(tester, repository);

    expect(find.text('No obligations'), findsOneWidget);

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();

    expect(find.text('No verified payments'), findsOneWidget);
  });
}
