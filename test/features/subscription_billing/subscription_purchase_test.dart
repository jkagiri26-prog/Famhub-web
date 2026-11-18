import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/subscription_billing/application/providers/subscription_purchase_provider.dart';
import 'package:famhub_app/features/subscription_billing/domain/models/subscription_purchase.dart';
import 'package:famhub_app/features/subscription_billing/domain/repositories/subscription_purchase_repository.dart';

class _FakeRepository implements SubscriptionPurchaseRepository {
  int planCalls = 0;
  int purchaseCalls = 0;
  String? lastPlanId;

  @override
  Future<List<SubscriptionPlan>> listPlans() async {
    planCalls++;
    return const [
      SubscriptionPlan(
        planId: 'plan-1',
        planKey: 'annual-personal',
        planName: 'Annual Personal',
        amount: 12000,
        currency: 'KES',
        billingCycle: 'yearly',
        isActive: true,
        features: {'seats': 1},
      ),
    ];
  }

  @override
  Future<SubscriptionPurchase> createOrReusePurchase({
    required String planId,
  }) async {
    purchaseCalls++;
    lastPlanId = planId;
    return const SubscriptionPurchase(
      subscriptionCycleId: 'cycle-1',
      planId: 'plan-1',
      planKey: 'annual-personal',
      planName: 'Annual Personal',
      amount: 12000,
      currency: 'KES',
      periodStart: null,
      periodEnd: null,
      status: 'pending',
    );
  }
}

void main() {
  group('Subscription purchase models', () {
    test('maps customer-facing annual plan fields', () {
      final plan = SubscriptionPlan.fromJson({
        'plan_id': 'plan-1',
        'plan_key': 'annual-personal',
        'plan_name': 'Annual Personal',
        'amount': 12000,
        'currency': 'KES',
        'billing_cycle': 'yearly',
        'is_active': true,
        'features_json': {'seats': 1},
      });

      expect(plan.planId, 'plan-1');
      expect(plan.planName, 'Annual Personal');
      expect(plan.amount, 12000);
      expect(plan.currency, 'KES');
      expect(plan.billingCycle, 'yearly');
      expect(plan.isActive, isTrue);
      expect(plan.features['seats'], 1);
    });

    test('maps pending cycle and subscriptionCycleId', () {
      final purchase = SubscriptionPurchase.fromJson({
        'subscription_cycle_id': 'cycle-1',
        'plan_id': 'plan-1',
        'plan_key': 'annual-personal',
        'plan_name': 'Annual Personal',
        'amount': 12000,
        'currency': 'KES',
        'period_start': '2026-12-31',
        'period_end': '2027-12-30',
        'status': 'pending',
      });

      expect(purchase.subscriptionCycleId, 'cycle-1');
      expect(purchase.isPending, isTrue);
      expect(purchase.isActive, isFalse);
      expect(purchase.periodStart, DateTime(2026, 12, 31));
    });
  });

  group('Subscription purchase providers', () {
    test('loads the authenticated annual plan catalog', () async {
      final repository = _FakeRepository();
      final container = ProviderContainer(
        overrides: [
          subscriptionPurchaseRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final plans = await container.read(subscriptionPlansProvider.future);

      expect(plans, hasLength(1));
      expect(plans.single.planId, 'plan-1');
      expect(repository.planCalls, 1);
    });

    test('creates or reuses a pending cycle by plan id only', () async {
      final repository = _FakeRepository();
      final container = ProviderContainer(
        overrides: [
          subscriptionPurchaseRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final purchase = await container.read(
        subscriptionPurchaseProvider('plan-1').future,
      );

      expect(purchase.subscriptionCycleId, 'cycle-1');
      expect(purchase.isPending, isTrue);
      expect(repository.lastPlanId, 'plan-1');
      expect(repository.purchaseCalls, 1);
    });
  });

  group('Subscription purchase contract', () {
    final repositorySource = File(
      'lib/features/subscription_billing/infrastructure/repositories/subscription_purchase_repository_impl.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20261116000002_annual_subscription_purchase_foundation.sql',
    ).readAsStringSync();
    final purchase = File(
      'supabase/migrations/20261112000009_annual_subscription_purchase.sql',
    ).readAsStringSync();
    final centre = File(
      'supabase/migrations/20261116000003_subscription_centre_read.sql',
    ).readAsStringSync();

    test('client uses only the two customer-safe RPCs', () {
      expect(repositorySource, contains('list_subscription_plans'));
      expect(
        repositorySource,
        contains('create_or_reuse_subscription_purchase'),
      );
      expect(repositorySource, isNot(contains('confirm_annual_subscription')));
      expect(repositorySource, isNot(contains('service_role')));
      expect(repositorySource, isNot(contains('p_amount')));
      expect(repositorySource, isNot(contains('p_currency')));
      expect(repositorySource, isNot(contains('subscription-billing')));
      expect(repositorySource, isNot(contains('functions.invoke')));
    });

    test('plan catalog is authenticated and customer-facing only', () {
      expect(migration, contains('system"."list_annual_subscription_plans'));
      expect(migration, contains('IF auth.uid() IS NULL'));
      expect(migration, contains("p.billing_cycle = 'yearly'"));
      expect(migration, contains("p.currency = 'KES'"));
      expect(migration, contains('p.amount > 0'));
      expect(migration, contains('p.features_json'));
      expect(migration, isNot(contains('p.obligation_id')));
      expect(migration, isNot(contains('p.invoice_id')));
    });

    test('cycle creation is self-scoped and reuses pending cycles', () {
      expect(
        migration,
        contains('system"."create_or_reuse_annual_subscription_purchase'),
      );
      expect(migration, contains('system.ensure_individual_billing_account'));
      expect(
        migration,
        contains('v_pending.plan_id IS DISTINCT FROM p_plan_id'),
      );
      expect(migration, contains("c.status = 'pending'"));
      expect(migration, contains('finance.create_annual_subscription'));
      expect(migration, contains('system.allocate_invoice_number'));
      expect(migration, isNot(contains('complete_annual_subscription')));
      expect(migration, isNot(contains('p_profile_id')));
      expect(migration, isNot(contains('p_entity_id')));
      expect(migration, isNot(contains('p_amount')));
      expect(migration, isNot(contains('p_currency')));
    });

    test(
      'an active annual purchase is returned without creating a new cycle',
      () {
        expect(
          migration,
          contains('v_active finance.subscription_cycles%ROWTYPE'),
        );
        expect(migration, contains("c.status = 'active'"));
        expect(migration, contains("a.status = 'active'"));
        expect(migration, contains('a.end_date > now()'));
        expect(
          migration,
          contains(
            'An active annual subscription for a different plan already exists',
          ),
        );
        expect(migration, contains('FOR UPDATE OF c'));
        expect(
          migration,
          contains(
            'SELECT v_active.id, v_plan.id, v_plan.plan_key, v_plan.plan_name',
          ),
        );
      },
    );

    test('cycle creation does not start M-Pesa or activate entitlement', () {
      expect(migration, isNot(contains('functions.invoke')));
      expect(
        migration,
        isNot(contains('INSERT INTO finance.payment_attempts')),
      );
      expect(migration, isNot(contains('complete_annual_subscription')));
      expect(migration, isNot(contains('finalize_mpesa_payment')));
    });

    test('both RPCs reject unauthenticated callers', () {
      final authChecks = 'IF auth.uid() IS NULL'.allMatches(migration).length;
      expect(authChecks, 2);
      expect(migration, contains("USING ERRCODE = '42501'"));
    });

    test('inactive or non-annual plans are unavailable', () {
      expect(migration, contains('is_active IS TRUE'));
      expect(migration, contains("billing_cycle = 'yearly'"));
      expect(migration, contains("currency = 'KES'"));
    });

    test('cycle creation is self-scoped and cannot target another user', () {
      expect(migration, contains('system.ensure_individual_billing_account'));
      expect(migration, isNot(contains('p_profile_id')));
      expect(migration, isNot(contains('p_entity_id')));
      expect(migration, isNot(contains('p_billing_account_id')));
      expect(migration, isNot(contains('p_obligation_id')));
    });

    test('cycle creation does not activate or confirm a subscription', () {
      expect(migration, isNot(contains('complete_annual_subscription')));
      expect(migration, isNot(contains('confirm_annual_subscription')));
      expect(migration, isNot(contains('finance.finalize_mpesa_payment')));
      expect(migration, contains("RETURN QUERY"));
    });

    test('centre read path is authenticated and ownership-scoped', () {
      expect(centre, contains('system"."get_my_subscription_centre'));
      expect(centre, contains('IF auth.uid() IS NULL'));
      expect(centre, contains("ba.account_type = 'individual'"));
      expect(centre, contains('ba.profile_id = v_profile_id'));
      expect(centre, contains('core.entity_members'));
      expect(centre, contains('em.can_manage IS TRUE'));
      expect(centre, contains('TO "authenticated"'));
      expect(centre, isNot(contains('TO "service_role"')));
      expect(centre, isNot(contains('CREATE TABLE')));
      expect(centre, isNot(contains('"obligation_id" uuid')));
      expect(centre, isNot(contains('"invoice_id" uuid')));
    });

    test('centre read path does not activate or confirm subscriptions', () {
      expect(centre, isNot(contains('complete_annual_subscription')));
      expect(centre, isNot(contains('confirm_annual_subscription')));
      expect(centre, isNot(contains('finalize_mpesa_payment')));
    });

    test('existing Nairobi annual rules remain the source of truth', () {
      expect(
        purchase,
        contains("v_period_start::timestamp AT TIME ZONE 'Africa/Nairobi'"),
      );
      expect(
        purchase,
        contains("(v_period_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi'"),
      );
      expect(migration, isNot(contains('Africa/Nairobi')));
    });
  });
}
