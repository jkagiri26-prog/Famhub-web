import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/subscription_billing/application/providers/subscription_purchase_provider.dart';
import 'package:famhub_app/features/subscription_billing/application/providers/subscription_centre_provider.dart';
import 'package:famhub_app/features/subscription_billing/domain/models/subscription_purchase.dart';
import 'package:famhub_app/features/subscription_billing/domain/models/subscription_centre_state.dart';
import 'package:famhub_app/features/subscription_billing/domain/repositories/subscription_purchase_repository.dart';
import 'package:famhub_app/features/subscription_billing/domain/repositories/subscription_centre_repository.dart';
import 'package:famhub_app/core/subscription/application/providers/subscription_entitlements_provider.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_entitlements.dart';
import 'package:famhub_app/features/subscription_billing/presentation/pages/subscription_centre_page.dart';

class _FakePurchaseRepository implements SubscriptionPurchaseRepository {
  int purchaseCalls = 0;
  String? lastPlanId;
  String status = 'pending';
  List<SubscriptionPlan> plans = const [
    SubscriptionPlan(
      planId: 'plan-1',
      planKey: 'annual-personal',
      planName: 'Annual Personal',
      amount: 12000,
      currency: 'KES',
      billingCycle: 'yearly',
      isActive: true,
      features: {'farm_management': true, 'marketplace': true},
    ),
    SubscriptionPlan(
      planId: 'plan-2',
      planKey: 'annual-pro',
      planName: 'Annual Pro',
      amount: 24000,
      currency: 'KES',
      billingCycle: 'yearly',
      isActive: true,
      features: {'logistics': true, 'agrovet': true},
    ),
    SubscriptionPlan(
      planId: 'plan-3',
      planKey: 'monthly-starter',
      planName: 'Monthly Starter',
      amount: 1200,
      currency: 'KES',
      billingCycle: 'monthly',
      isActive: true,
      features: {'farm_management': true},
    ),
    SubscriptionPlan(
      planId: 'plan-4',
      planKey: 'quarterly-growth',
      planName: 'Quarterly Growth',
      amount: 3600,
      currency: 'KES',
      billingCycle: 'quarterly',
      isActive: true,
      features: {'logistics': true},
    ),
  ];
  Completer<SubscriptionPurchase>? gate;

  @override
  Future<List<SubscriptionPlan>> listPlans() async => plans;

  @override
  Future<SubscriptionPurchase> createOrReusePurchase({
    required String planId,
  }) async {
    purchaseCalls++;
    lastPlanId = planId;
    if (gate != null) return gate!.future;
    return SubscriptionPurchase(
      subscriptionCycleId: 'cycle-1',
      planId: 'plan-1',
      planKey: 'annual-personal',
      planName: 'Annual Personal',
      amount: 12000,
      currency: 'KES',
      periodStart: null,
      periodEnd: null,
      status: status,
    );
  }
}

class _FakeCentreRepository implements SubscriptionCentreRepository {
  SubscriptionCentreState state = SubscriptionCentreState.empty;
  SubscriptionCentreState? nextState;
  int fetchCalls = 0;
  int initiateCalls = 0;
  String initiationStatus = 'pending';
  String? lastCycleId;
  String? lastPhone;
  String? lastKey;
  Object? initiateError;
  Completer<SubscriptionInitiation>? gate;

  @override
  Future<SubscriptionCentreState> fetchState() async {
    fetchCalls++;
    final next = nextState;
    if (next != null) {
      nextState = null;
      state = next;
    }
    return state;
  }

  @override
  Future<SubscriptionInitiation> initiatePayment({
    required String subscriptionCycleId,
    required String phone,
    required String idempotencyKey,
  }) async {
    initiateCalls++;
    lastCycleId = subscriptionCycleId;
    lastPhone = phone;
    lastKey = idempotencyKey;
    if (gate != null) return gate!.future;
    if (initiateError != null) throw initiateError!;
    return SubscriptionInitiation(
      status: initiationStatus,
      paymentAttemptId: 'attempt-1',
      checkoutRequestId: 'checkout-1',
    );
  }
}

SubscriptionCentreEntry _entry({
  String cycleId = 'cycle-1',
  String cycleStatus = 'pending',
  bool isActive = false,
  bool isPending = true,
  String ownerType = 'individual',
  String billingCycle = 'yearly',
  String planId = 'plan-1',
  String planName = 'Annual Personal',
  double amount = 12000,
  DateTime? activeStart,
  DateTime? activeEnd,
}) {
  return SubscriptionCentreEntry(
    billingAccountId: 'billing-1',
    billingOwnerType: ownerType,
    planId: planId,
    planKey: 'plan-key-$planId',
    planName: planName,
    billingCycle: billingCycle,
    amount: amount,
    currency: 'KES',
    subscriptionCycleId: cycleId,
    cycleStatus: cycleStatus,
    periodStart: DateTime.utc(2026, 12, 31),
    periodEnd: DateTime.utc(2027, 12, 30),
    settledAt: isActive ? DateTime.utc(2026, 12, 31) : null,
    activeStatus: isActive ? 'active' : 'pending',
    activeStart: activeStart ?? DateTime.utc(2026, 12, 30, 21),
    activeEnd: activeEnd,
    isActive: isActive,
    isPending: isPending,
    paymentAttemptStatus: 'pending',
  );
}

Widget _app(
  WidgetTester tester, {
  required _FakePurchaseRepository purchases,
  required _FakeCentreRepository centre,
  SubscriptionEntitlements? entitlements,
}) {
  return ProviderScope(
    overrides: [
      subscriptionPurchaseRepositoryProvider.overrideWithValue(purchases),
      subscriptionCentreRepositoryProvider.overrideWithValue(centre),
      if (entitlements != null)
        subscriptionEntitlementsProvider.overrideWith(
          (ref) async => entitlements,
        ),
    ],
    child: const MaterialApp(home: Scaffold(body: SubscriptionCentrePage())),
  );
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tapPay(WidgetTester tester) async {
  final button = find.text('Pay with M-Pesa');
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
}

Future<void> _tapPayAndContinue(WidgetTester tester) async {
  await _tapPay(tester);
  final confirm = find.text('Continue');
  if (confirm.evaluate().isNotEmpty) {
    await tester.tap(confirm);
    await tester.pump();
  }
}

void main() {
  testWidgets('shows universal plan catalogue and cross-workspace features', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    expect(find.text('Subscription Centre'), findsOneWidget);
    expect(find.text('Annual Personal'), findsOneWidget);
    expect(find.text('Annual Pro'), findsOneWidget);
    expect(find.text('Monthly Starter'), findsOneWidget);
    expect(find.text('Quarterly Growth'), findsOneWidget);
    expect(find.text('KES 12000 / yearly'), findsOneWidget);
    expect(find.text('KES 24000 / yearly'), findsOneWidget);
    expect(find.text('KES 1200 / monthly'), findsOneWidget);
    expect(find.text('KES 3600 / quarterly'), findsOneWidget);
    expect(find.text('farm_management'), findsWidgets);
    expect(find.text('logistics'), findsWidgets);
  });

  testWidgets('monthly plan is selectable and reaches the billing flow', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    await tester.tap(find.text('Monthly Starter'));
    await tester.enterText(find.byType(TextField), '0712345678');
    await _tapPayAndContinue(tester);
    await _pumpPage(tester);

    expect(purchases.lastPlanId, 'plan-3');
    expect(centre.lastCycleId, 'cycle-1');
    expect(centre.initiateCalls, 1);
  });

  testWidgets('quarterly plan is selectable and reaches the billing flow', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    await tester.ensureVisible(find.text('Quarterly Growth'));
    await tester.pump();
    await tester.tap(find.text('Quarterly Growth'));
    await tester.enterText(find.byType(TextField), '0712345678');
    await _tapPayAndContinue(tester);
    await _pumpPage(tester);

    expect(purchases.lastPlanId, 'plan-4');
    expect(centre.lastCycleId, 'cycle-1');
    expect(centre.initiateCalls, 1);
  });

  testWidgets('shows an honest state when no annual plans are available', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository()..plans = const [];
    final centre = _FakeCentreRepository();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    expect(
      find.text('No subscription plans are available yet.'),
      findsOneWidget,
    );
    expect(find.text('Pay with M-Pesa'), findsNothing);
  });

  testWidgets('purchase confirmation shows canonical plan price and currency', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    await tester.tap(find.text('Annual Personal'));
    await tester.enterText(find.byType(TextField), '0712 345 678');
    await _tapPay(tester);

    expect(find.text('Confirm subscription'), findsOneWidget);
    expect(find.textContaining('KES 12000 / yearly'), findsWidgets);
    expect(find.textContaining('254712345678'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await _pumpPage(tester);
    expect(purchases.purchaseCalls, 0);
    expect(centre.initiateCalls, 0);

    await _tapPayAndContinue(tester);
    await _pumpPage(tester);
    expect(purchases.purchaseCalls, 1);
    expect(centre.initiateCalls, 1);
  });

  testWidgets('shows creating-cycle state before provider initiation', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository()
      ..gate = Completer<SubscriptionPurchase>();
    final centre = _FakeCentreRepository();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    await tester.tap(find.text('Annual Personal'));
    await tester.enterText(find.byType(TextField), '0712345678');
    await _tapPayAndContinue(tester);
    await tester.pump();

    expect(find.text('Creating your subscription…'), findsOneWidget);
    expect(centre.initiateCalls, 0);

    purchases.gate!.complete(
      const SubscriptionPurchase(
        subscriptionCycleId: 'cycle-1',
        planId: 'plan-1',
        planKey: 'annual-personal',
        planName: 'Annual Personal',
        amount: 12000,
        currency: 'KES',
        periodStart: null,
        periodEnd: null,
        status: 'pending',
      ),
    );
    await _pumpPage(tester);
    expect(centre.initiateCalls, 1);
  });

  testWidgets(
    'provider success remains processing until backend state is active',
    (tester) async {
      final purchases = _FakePurchaseRepository();
      final centre = _FakeCentreRepository()..initiationStatus = 'succeeded';
      await tester.pumpWidget(
        _app(tester, purchases: purchases, centre: centre),
      );
      await _pumpPage(tester);

      await tester.tap(find.text('Annual Personal'));
      await tester.enterText(find.byType(TextField), '0712345678');
      await _tapPayAndContinue(tester);
      await _pumpPage(tester);

      expect(find.textContaining('Processing payment'), findsOneWidget);
      expect(find.textContaining('Your subscription is active'), findsNothing);
    },
  );

  testWidgets('rejects invalid phone before repository invocation', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    await tester.tap(find.text('Annual Personal'));
    await tester.enterText(find.byType(TextField), '123');
    await _tapPayAndContinue(tester);
    await _pumpPage(tester);

    expect(
      find.text('Enter a valid Safaricom number, e.g. 0712 345 678.'),
      findsOneWidget,
    );
    expect(purchases.purchaseCalls, 0);
    expect(centre.initiateCalls, 0);
  });

  testWidgets('sends the selected plan, normalized phone, and stable key', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    await tester.tap(find.text('Annual Personal'));
    await tester.enterText(find.byType(TextField), '0712 345 678');
    await _tapPayAndContinue(tester);
    await _pumpPage(tester);

    expect(purchases.lastPlanId, 'plan-1');
    expect(centre.lastCycleId, 'cycle-1');
    expect(centre.lastPhone, '254712345678');
    expect(centre.lastKey, 'subscription-cycle-1');
    expect(
      find.textContaining('Waiting for M-Pesa confirmation'),
      findsOneWidget,
    );
  });

  testWidgets('provider unavailable is shown clearly', (tester) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..initiateError = const SubscriptionProviderUnavailable();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    await tester.tap(find.text('Annual Personal'));
    await tester.enterText(find.byType(TextField), '0712345678');
    await _tapPayAndContinue(tester);
    await _pumpPage(tester);

    expect(
      find.text(
        'M-Pesa is temporarily unavailable. No payment was taken. Please try again shortly.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('provider unavailable can be retried', (tester) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..initiateError = const SubscriptionProviderUnavailable();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    await tester.tap(find.text('Annual Personal'));
    await tester.enterText(find.byType(TextField), '0712345678');
    await _tapPayAndContinue(tester);
    await _pumpPage(tester);
    expect(find.text('Try again'), findsOneWidget);

    centre.initiateError = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await _pumpPage(tester);
    expect(centre.initiateCalls, 2);
    expect(
      find.textContaining('Waiting for M-Pesa confirmation'),
      findsOneWidget,
    );
  });

  testWidgets('definitive failure offers retry and does not show active', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..initiateError = const SubscriptionPaymentRejected();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    await tester.tap(find.text('Annual Personal'));
    await tester.enterText(find.byType(TextField), '0712345678');
    await _tapPayAndContinue(tester);
    await _pumpPage(tester);

    expect(
      find.text(
        'The payment was not completed. Your subscription is still inactive.',
      ),
      findsOneWidget,
    );
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('repeated taps do not create duplicate purchase or initiation', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..gate = Completer<SubscriptionInitiation>();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    await tester.tap(find.text('Annual Personal'));
    await tester.enterText(find.byType(TextField), '0712345678');
    await _tapPayAndContinue(tester);
    await tester.pump();
    await tester.tap(find.text('Pay with M-Pesa'), warnIfMissed: false);
    await tester.pump();

    expect(purchases.purchaseCalls, 1);
    expect(centre.initiateCalls, 1);

    centre.gate!.complete(
      const SubscriptionInitiation(
        status: 'pending',
        paymentAttemptId: 'attempt-1',
        checkoutRequestId: 'checkout-1',
      ),
    );
    await _pumpPage(tester);
  });

  testWidgets('active monthly subscription shows authoritative details', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..state = SubscriptionCentreState(
        entries: [
          _entry(
            planId: 'plan-3',
            planName: 'Monthly Starter',
            billingCycle: 'monthly',
            amount: 1200,
            isActive: true,
            isPending: false,
            cycleStatus: 'active',
            activeStart: DateTime(2026, 1, 1),
            activeEnd: DateTime(2026, 2, 1),
          ),
        ],
      );
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    expect(find.textContaining('Your subscription is active'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('KES 1200'), findsOneWidget);
    expect(find.text('Current period'), findsOneWidget);
    expect(find.text('2026-01-01 – 2026-02-01'), findsOneWidget);
  });

  testWidgets('active quarterly subscription shows authoritative details', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..state = SubscriptionCentreState(
        entries: [
          _entry(
            planId: 'plan-4',
            planName: 'Quarterly Growth',
            billingCycle: 'quarterly',
            amount: 3600,
            isActive: true,
            isPending: false,
            cycleStatus: 'active',
            activeEnd: DateTime.utc(2026, 4, 1),
          ),
        ],
      );
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    expect(find.textContaining('Your subscription is active'), findsOneWidget);
    expect(find.text('Quarterly'), findsOneWidget);
    expect(find.text('KES 3600'), findsOneWidget);
  });

  testWidgets('active yearly subscription displays capabilities', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..state = SubscriptionCentreState(
        entries: [
          _entry(
            isActive: true,
            isPending: false,
            cycleStatus: 'active',
            activeEnd: DateTime.utc(2027, 12, 30, 21),
          ),
        ],
      );
    final entitlements = SubscriptionEntitlements.fromRows([
      {
        'entity_id': 'entity-1',
        'billing_owner_type': 'individual',
        'plan_name': 'Annual Personal',
        'billing_cycle': 'yearly',
        'start_date': '2026-12-31T21:00:00Z',
        'end_date': '2027-12-30T21:00:00Z',
        'is_active': true,
        'is_future': false,
        'is_expired': false,
        'capabilities': ['farm.management', 'marketplace.listings'],
      },
    ]);
    await tester.pumpWidget(
      _app(
        tester,
        purchases: purchases,
        centre: centre,
        entitlements: entitlements,
      ),
    );
    await _pumpPage(tester);

    expect(find.textContaining('Your subscription is active'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
    expect(find.text('farm.management'), findsOneWidget);
    expect(find.text('marketplace.listings'), findsOneWidget);
  });

  testWidgets(
    'active subscription prevents an inappropriate duplicate purchase',
    (tester) async {
      final purchases = _FakePurchaseRepository();
      final centre = _FakeCentreRepository()
        ..state = SubscriptionCentreState(
          entries: [
            _entry(
              isActive: true,
              isPending: false,
              cycleStatus: 'active',
              activeEnd: DateTime.utc(2027, 12, 30, 21),
            ),
          ],
        );
      await tester.pumpWidget(
        _app(tester, purchases: purchases, centre: centre),
      );
      await _pumpPage(tester);

      expect(
        find.textContaining('Your subscription is active'),
        findsOneWidget,
      );
      expect(find.text('Pay with M-Pesa'), findsNothing);
      expect(purchases.purchaseCalls, 0);
    },
  );

  testWidgets('no active subscription is shown without entitlement claims', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository();
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    expect(find.textContaining('No active subscription'), findsOneWidget);
    expect(find.textContaining('Your subscription is active'), findsNothing);
  });

  testWidgets('pending purchase recovers and refreshes to active', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..state = SubscriptionCentreState(entries: [_entry()]);
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    expect(find.textContaining('is pending payment'), findsOneWidget);

    centre.state = SubscriptionCentreState(
      entries: [
        _entry(
          isActive: true,
          isPending: false,
          cycleStatus: 'active',
          activeEnd: DateTime.utc(2027, 12, 30, 21),
        ),
      ],
    );
    await tester.pump(const Duration(seconds: 5));
    await _pumpPage(tester);

    expect(find.textContaining('Your subscription is active'), findsOneWidget);
    expect(find.textContaining('Individual billing'), findsOneWidget);
  });

  testWidgets('entity-owned subscription is visibly entity billing', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..state = SubscriptionCentreState(
        entries: [
          _entry(
            ownerType: 'entity',
            isActive: true,
            isPending: false,
            cycleStatus: 'active',
            activeEnd: DateTime.utc(2027, 12, 30, 21),
          ),
        ],
      );
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    expect(find.textContaining('Entity billing'), findsOneWidget);
  });

  testWidgets('subscription history is shown from backend state', (
    tester,
  ) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..state = SubscriptionCentreState(
        entries: [
          _entry(
            isPending: false,
            cycleStatus: 'expired',
            activeEnd: DateTime.utc(2025, 12, 30, 21),
          ),
        ],
      );
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    expect(find.text('Subscription history'), findsOneWidget);
    expect(find.text('Annual Personal'), findsWidgets);
  });

  testWidgets('expired subscription is clear', (tester) async {
    final purchases = _FakePurchaseRepository();
    final centre = _FakeCentreRepository()
      ..state = SubscriptionCentreState(
        entries: [
          _entry(
            isPending: false,
            cycleStatus: 'expired',
            activeEnd: DateTime.utc(2025, 12, 30, 21),
          ),
        ],
      );
    await tester.pumpWidget(_app(tester, purchases: purchases, centre: centre));
    await _pumpPage(tester);

    expect(find.textContaining('subscription has expired'), findsOneWidget);
  });

  test('shared entry point and confirmation boundary are safe', () {
    final routes = File('lib/core/router/route_names.dart').readAsStringSync();
    final registrar = File(
      'lib/core/composition/router/dynamic_route_registrar.dart',
    ).readAsStringSync();
    final appBar = File(
      'lib/core/shell/presentation/regions/shell_app_bar.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/features/subscription_billing/infrastructure/repositories/subscription_centre_repository_impl.dart',
    ).readAsStringSync();

    expect(routes, contains("subscription = '/subscription'"));
    expect(registrar, contains('AppRoutes.subscription'));
    expect(appBar, contains('AppRoutes.subscription'));
    expect(repository, contains("'action': 'initiate'"));
    expect(repository, contains("'subscriptionCycleId': subscriptionCycleId"));
    expect(repository, contains("'phone': phone"));
    expect(repository, contains("'idempotencyKey': idempotencyKey"));
    expect(repository, isNot(contains('confirm_annual_subscription')));
    expect(repository, isNot(contains('service_role')));
    expect(repository, isNot(contains('p_amount')));
    expect(repository, isNot(contains('p_currency')));
  });
}
