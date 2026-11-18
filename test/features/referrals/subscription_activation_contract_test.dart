import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level checks for the annual subscription activation migration.
void main() {
  final source = File(
    'supabase/migrations/20261112000012_annual_subscription_activation.sql',
  ).readAsStringSync();

  group('Subscription activation contract', () {
    test('completion function has the expected service-role surface', () {
      expect(source, contains('finance"."complete_annual_subscription'));
      expect(source, contains('"p_subscription_cycle_id" uuid'));
      expect(source, contains('"p_obligation_id" uuid DEFAULT NULL'));
      expect(source, contains('SECURITY DEFINER'));
      expect(source, contains('TO "service_role"'));
      expect(source, isNot(contains('TO "authenticated"')));
    });

    test('consumes authoritative Finance settlement', () {
      expect(source, contains("v_obligation.status <> 'settled'"));
      expect(source, contains('finance.obligation_settlements'));
      expect(source, contains('sum(s.amount)'));
      expect(source, contains("s.currency <> v_obligation.currency"));
      expect(source, contains('finance.payments'));
      expect(source, contains('p.verified_at IS NULL'));
      expect(source, contains('finance.payment_attempts'));
      expect(source, contains("a.status <> 'succeeded'"));
    });

    test('uses stored cycle dates and does not post journals', () {
      expect(source, contains('v_cycle.period_start'));
      expect(source, contains('v_cycle.period_end'));
      expect(
        source,
        contains("v_cycle.period_start::timestamp AT TIME ZONE 'Africa/Nairobi'"),
      );
      expect(
        source,
        contains("(v_cycle.period_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi'"),
      );
      expect(source, contains('status = \'paid\''));
      expect(source, contains('paid_at = coalesce'));
      expect(source, contains('status = \'active\''));
      expect(source, isNot(contains('finance.post_journal')));
      expect(source, isNot(contains('INSERT INTO finance.journals')));
      expect(source, isNot(contains('INSERT INTO finance.journal_lines')));
      expect(source, isNot(contains('referrals.')));
    });

    test('emits one durable idempotent activation event', () {
      expect(source, contains('finance.subscription.annual.activated'));
      expect(source, contains('finance.subscription_cycle'));
      expect(source, contains('subscription-cycle-activated:'));
      expect(source, contains('INSERT INTO finance.events'));
      expect(source, contains('ON CONFLICT (idempotency_key) DO NOTHING'));
      expect(
        source,
        contains('Existing activation event has a conflicting payload'),
      );
      expect(
        source,
        contains('Completed subscription has no activation event'),
      );
      expect(
        source,
        contains('Completed active subscription dates do not match'),
      );
      expect(source, contains('Completed invoice paid_at does not match'));
      expect(source, contains('settlement_id'));
      expect(source, contains('payment_id'));
      expect(source, contains('annual_sequence'));
      expect(source, contains('cycle_type'));
    });

    test('locks rows for concurrent completion safety', () {
      expect(source, contains('FROM finance.subscription_cycles'));
      expect(source, contains('FOR UPDATE'));
      expect(source, contains('FROM finance.obligations'));
      expect(source, contains('FROM system.active_subscriptions'));
      expect(source, contains('FROM system.invoices'));
    });
  });
}
