import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/subscription_billing/domain/models/subscription_purchase.dart';

void main() {
  final migration = File(
    'supabase/migrations/20261116000005_subscription_frequency_purchase.sql',
  ).readAsStringSync();
  final repository = File(
    'lib/features/subscription_billing/infrastructure/repositories/subscription_purchase_repository_impl.dart',
  ).readAsStringSync();
  final centreRead = File(
    'supabase/migrations/20261116000006_subscription_centre_state_frequency.sql',
  ).readAsStringSync();

  group('Frequency-aware subscription purchase contract', () {
    test('purchase model retains backend billing frequency', () {
      final purchase = SubscriptionPurchase.fromJson({
        'subscription_cycle_id': 'cycle-1',
        'plan_id': 'plan-1',
        'plan_key': 'monthly-starter',
        'plan_name': 'Monthly Starter',
        'billing_cycle': 'monthly',
        'amount': 1200,
        'currency': 'KES',
        'status': 'pending',
      });

      expect(purchase.billingCycle, 'monthly');
      expect(purchase.subscriptionCycleId, 'cycle-1');
    });

    test('uses the canonical monthly, quarterly and yearly frequencies', () {
      expect(migration, contains("'monthly', 'quarterly', 'yearly'"));
      expect(migration, contains('v_frequency := v_plan.billing_cycle'));
      expect(migration, contains('initial_monthly'));
      expect(migration, contains('renewal_monthly'));
      expect(migration, contains('initial_quarterly'));
      expect(migration, contains('renewal_quarterly'));
      expect(migration, contains("WHEN 'yearly' THEN 'annual'"));
      expect(migration, isNot(contains('multi_year')));
    });

    test('periods are calendar-based, not fixed days or seconds', () {
      expect(migration, contains("interval '1 month'"));
      expect(migration, contains("interval '3 months'"));
      expect(migration, contains("interval '1 year'"));
      expect(migration, isNot(contains("interval '30 days'")));
      expect(migration, isNot(contains("interval '90 days'")));
      expect(migration, isNot(contains("interval '365 days'")));
      expect(migration, isNot(contains("interval '3600 seconds'")));
    });

    test('Nairobi business dates and UTC active boundaries are explicit', () {
      expect(
        migration,
        contains("(now() AT TIME ZONE 'Africa/Nairobi')::date"),
      );
      expect(
        migration,
        contains("v_period_start::timestamp AT TIME ZONE 'Africa/Nairobi'"),
      );
      expect(
        migration,
        contains("(v_period_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi'"),
      );
    });

    test('client cannot choose price, currency, frequency or dates', () {
      expect(migration, contains('p_plan_id'));
      expect(
        migration,
        contains('system"."create_or_reuse_subscription_purchase'),
      );
      expect(migration, isNot(contains('p_amount')));
      expect(migration, isNot(contains('p_currency')));
      expect(migration, isNot(contains('p_billing_cycle')));
      expect(migration, isNot(contains('p_period_start')));
      expect(migration, isNot(contains('p_period_end')));
    });

    test('pending and active protections are frequency-independent', () {
      expect(migration, contains("c.status = 'pending'"));
      expect(migration, contains("c.status = 'active'"));
      expect(migration, contains("a.status = 'active'"));
      expect(
        migration,
        contains('A different subscription plan is already pending'),
      );
      expect(
        migration,
        contains('An active subscription for a different plan already exists'),
      );
      expect(migration, contains('FOR UPDATE OF c'));
    });

    test('purchase still does not activate entitlement', () {
      expect(migration, isNot(contains('complete_annual_subscription')));
      expect(migration, isNot(contains('finalize_mpesa_payment')));
      expect(migration, isNot(contains('confirm_annual_subscription')));
      expect(migration, isNot(contains('INSERT INTO finance.payments')));
    });

    test('centre read state exposes canonical plan billing frequency', () {
      expect(centreRead, contains('plan.billing_cycle'));
      expect(centreRead, contains('"billing_cycle" text'));
      expect(centreRead, isNot(contains('CREATE TABLE')));
      expect(centreRead, isNot(contains('payment_attempts SET')));
    });

    test('Flutter uses the frequency-aware RPCs', () {
      expect(repository, contains('list_subscription_plans'));
      expect(repository, contains('create_or_reuse_subscription_purchase'));
      expect(repository, isNot(contains('list_annual_subscription_plans')));
      expect(
        repository,
        isNot(contains('create_or_reuse_annual_subscription_purchase')),
      );
    });
  });
}
