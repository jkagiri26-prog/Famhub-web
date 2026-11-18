import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level checks for the subscription -> Finance M-Pesa bridge.
///
/// These tests do not connect to Supabase and do not execute SQL.
void main() {
  final bridge = File(
    'supabase/migrations/20261116000001_subscription_mpesa_billing.sql',
  );
  final purchase = File(
    'supabase/migrations/20261112000009_annual_subscription_purchase.sql',
  );
  final activation = File(
    'supabase/migrations/20261112000012_annual_subscription_activation.sql',
  );
  final flowTest = File(
    'supabase/tests/subscription_mpesa_billing_flow_test.sql',
  );

  group('Subscription M-Pesa billing contract', () {
    test('bridge reuses existing Finance and subscription functions', () {
      final source = bridge.readAsStringSync();

      expect(
        source,
        contains('finance"."request_annual_subscription_mpesa_attempt'),
      );
      expect(
        source,
        contains('finance"."confirm_annual_subscription_payment'),
      );
      expect(source, contains('finance.request_mpesa_attempt'));
      expect(source, contains('finance.finalize_mpesa_payment'));
      expect(source, contains('finance.complete_annual_subscription'));
      expect(source, contains('finance.subscription_cycles'));
      expect(source, contains('system.active_subscriptions'));
      expect(source, contains('system.invoices'));
      expect(source, contains('finance.payment_attempts'));
    });

    test('bridge adds no payment table, ledger, or Daraja coupling', () {
      final source = bridge.readAsStringSync();

      expect(source, isNot(contains('CREATE TABLE')));
      expect(source, isNot(contains('INSERT INTO finance.payments')));
      expect(source, isNot(contains('INSERT INTO finance.journals')));
      expect(source, isNot(contains('INSERT INTO finance.journal_lines')));
      expect(source, isNot(contains('CREATE TABLE')));
      expect(source, isNot(contains('daraja')));
      expect(source, isNot(contains('stk')));
      expect(source, isNot(contains('callback_secret')));
    });

    test('payment start is authenticated and confirmation is service-only', () {
      final source = bridge.readAsStringSync();

      expect(source, contains('SECURITY DEFINER'));
      expect(source, contains('GRANT EXECUTE'));
      expect(
        source,
        contains(
          'request_annual_subscription_mpesa_attempt"(uuid, text, text)\n    TO "authenticated"',
        ),
      );
      expect(
        source,
        contains(
          'confirm_annual_subscription_payment"(uuid, uuid)\n    TO "service_role"',
        ),
      );
      expect(source, contains("v_cycle.subscriber_profile_id IS DISTINCT FROM v_profile_id"));
      expect(source, contains('Caller does not own this subscription cycle'));
    });

    test('existing purchase and activation retain Nairobi boundary rules', () {
      final purchaseSource = purchase.readAsStringSync();
      final activationSource = activation.readAsStringSync();

      expect(
        purchaseSource,
        contains("v_period_start::timestamp AT TIME ZONE 'Africa/Nairobi'"),
      );
      expect(
        purchaseSource,
        contains("(v_period_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi'"),
      );
      expect(
        activationSource,
        contains(
          "v_cycle.period_start::timestamp AT TIME ZONE 'Africa/Nairobi'",
        ),
      );
      expect(
        activationSource,
        contains(
          "(v_cycle.period_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi'",
        ),
      );
    });

    test('behavior test covers success, failure, idempotency, and boundaries', () {
      final source = flowTest.readAsStringSync();

      expect(source, contains('request_annual_subscription_mpesa_attempt'));
      expect(source, contains('confirm_annual_subscription_payment'));
      expect(source, contains('obligation_id = v_obligation_id'));
      expect(source, contains('successful payment did not activate subscription'));
      expect(source, contains('failed payment activated the subscription'));
      expect(source, contains('duplicate confirmation duplicated payment truth'));
      expect(source, contains("'2026-12-30 21:00:00+00'::timestamptz"));
      expect(source, contains("'2027-12-30 21:00:00+00'::timestamptz"));
      expect(source, contains('ROLLBACK'));
    });
  });
}
