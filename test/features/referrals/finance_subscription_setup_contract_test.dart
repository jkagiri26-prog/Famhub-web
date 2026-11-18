import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level contract checks for the Finance account setup and annual
/// subscription infrastructure migrations.
///
/// These tests do not connect to Supabase and do not execute SQL.
void main() {
  final directory = Directory('supabase/migrations');
  final files = directory
      .listSync()
      .whereType<File>()
      .where(
        (file) =>
            file.path.endsWith('20261112000006_finance_referral_accounts.sql') ||
            file.path.endsWith(
              '20261112000007_subscription_cycle_idempotency.sql',
            ) ||
            file.path.endsWith('20261112000008_annual_subscription_plans.sql') ||
            file.path.endsWith(
              '20261112000009_annual_subscription_purchase.sql',
            ),
      )
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  String readAll() => files.map((file) => file.readAsStringSync()).join('\n');

  group('Finance account setup contract', () {
    test('new migrations exist in dependency order', () {
      final names = files.map((file) => file.path.split('/').last).toList();

      expect(
        names,
        containsAllInOrder([
          '20261112000006_finance_referral_accounts.sql',
          '20261112000007_subscription_cycle_idempotency.sql',
          '20261112000008_annual_subscription_plans.sql',
          '20261112000009_annual_subscription_purchase.sql',
        ]),
      );
    });

    test('adds 5200 and a supplied payable account without hardcoded IDs', () {
      final source = files
          .firstWhere(
            (file) =>
                file.path.endsWith('20261112000006_finance_referral_accounts.sql'),
          )
          .readAsStringSync();

      expect(source, contains('finance"."referral_account_settings'));
      expect(source, contains('finance"."ensure_referral_accounts'));
      expect(source, contains("'5200'"));
      expect(source, contains('Referral Reward Expense'));
      expect(source, contains('p_payable_account_code'));
      expect(source, contains('p_payable_account_name'));
      expect(source, contains("'liability'"));
      expect(source, contains("'credit'"));
      expect(source, contains("'expense'"));
      expect(source, contains("'debit'"));
      expect(source, contains('platform_administration'));
      expect(source, contains('GRANT EXECUTE'));
      expect(source, contains('TO "service_role"'));
    });

    test('does not open accounting periods or post journals', () {
      final source = readAll();

      expect(source, isNot(contains('INSERT INTO finance.accounting_periods')));
      expect(source, isNot(contains('finance.post_journal')));
      expect(source, isNot(contains('create_accounting_period')));
    });

    test('does not create M-Pesa or payout authority', () {
      final source = readAll();

      expect(source, isNot(contains('stk-push')));
      expect(source, isNot(contains('mpesa_callback')));
      expect(source, isNot(contains('system.payout_requests')));
      expect(source, isNot(contains('system.payout_disbursements')));
    });

    test('adds caller idempotency to subscription cycles', () {
      final source = files
          .firstWhere(
            (file) => file.path.endsWith(
              '20261112000007_subscription_cycle_idempotency.sql',
            ),
          )
          .readAsStringSync();

      expect(source, contains('ADD COLUMN IF NOT EXISTS "idempotency_key" text'));
      expect(source, contains('subscription_cycles_idempotency_key_key'));
      expect(source, contains('subscription_cycles_idempotency_key_check'));
    });

    test('creates annual KES plans with supplied amounts', () {
      final source = files
          .firstWhere(
            (file) =>
                file.path.endsWith('20261112000008_annual_subscription_plans.sql'),
          )
          .readAsStringSync();

      expect(source, contains('system"."create_annual_subscription_plan'));
      expect(source, contains("'yearly'"));
      expect(source, contains("'KES'"));
      expect(source, contains('p_amount'));
      expect(source, contains('p_plan_key'));
      expect(source, contains('TO "service_role"'));
    });

    test('creates annual purchases with invoice, obligation and cycle link', () {
      final source = files
          .firstWhere(
            (file) => file.path.endsWith(
              '20261112000009_annual_subscription_purchase.sql',
            ),
          )
          .readAsStringSync();

      expect(source, contains('finance"."create_annual_subscription'));
      expect(source, contains('p_invoice_number'));
      expect(source, contains('p_idempotency_key'));
      expect(source, contains('system.invoices'));
      expect(source, contains('system.invoice_items'));
      expect(source, contains('system.active_subscriptions'));
      expect(
        source,
        contains("v_period_start::timestamp AT TIME ZONE 'Africa/Nairobi'"),
      );
      expect(
        source,
        contains("(v_period_end + 1)::timestamp AT TIME ZONE 'Africa/Nairobi'"),
      );
      expect(source, contains('finance.create_obligation'));
      expect(source, contains('finance.subscription_cycles'));
      expect(source, contains("'initial_annual'"));
      expect(source, contains("'renewal_annual'"));
      expect(source, contains('previous period end'));
      expect(source, contains('No retroactive access'));
      expect(source, contains('individual_pro'));
      expect(source, contains('account_type <> \'individual\''));
      expect(source, contains('v_account.currency <> \'KES\''));
      expect(source, contains('TO "service_role"'));
    });
  });
}
