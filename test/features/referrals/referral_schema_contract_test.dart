import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level contract checks for the first Refer & Earn backend migrations.
///
/// These tests do not connect to Supabase and do not execute SQL. They assert
/// that the version-controlled migrations keep the approved structural rules.
void main() {
  final migrationDirectory = Directory('supabase/migrations');
  final files =
      migrationDirectory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('2026111200000'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  String readAllMigrations() =>
      files.map((file) => file.readAsStringSync()).join('\n');

  String tableBlock(String source, String header) {
    final start = source.indexOf(header);
    if (start < 0) return '';
    final end = source.indexOf('\n);', start);
    if (end < 0) return '';
    return source.substring(start, end);
  }

  group('Refer & Earn migration contract', () {
    test('migration files exist in dependency order', () {
      final names = files.map((file) => file.path.split('/').last).toList();

      expect(
        names,
        containsAllInOrder([
          '20261112000001_finance_subscription_cycles.sql',
          '20261112000002_finance_events_outbox.sql',
          '20261112000003_referrals_core_schema.sql',
          '20261112000004_referrals_event_delivery.sql',
          '20261112000005_referrals_withdrawal_schema.sql',
        ]),
      );
    });

    test('uses the singular canonical referrals schema only', () {
      final source = readAllMigrations();

      expect(source, contains('CREATE SCHEMA IF NOT EXISTS "referrals";'));
      expect(
        RegExp(r'CREATE SCHEMA IF NOT EXISTS "referral";').hasMatch(source),
        isFalse,
      );
    });

    test(
      'separates permanent subscription-cycle history from active access',
      () {
        final source = readAllMigrations();

        expect(
          source,
          contains(
            'CREATE TABLE IF NOT EXISTS "finance"."subscription_cycles"',
          ),
        );
        expect(source, contains('"active_subscription_id" uuid'));
        expect(source, contains('"annual_sequence" integer NOT NULL'));
        expect(source, contains('"cycle_type" text NOT NULL'));
        expect(source, contains('"previous_cycle_id" uuid'));
        expect(source, contains('"invoice_id" uuid NOT NULL'));
        expect(source, contains('"obligation_id" uuid NOT NULL'));
        expect(source, contains('subscription_cycles_invoice_id_key'));
        expect(source, contains('subscription_cycles_obligation_id_key'));
        expect(source, contains('subscription_cycles_subscriber_sequence_key'));
        expect(source, contains('subscription_cycles_initial_sequence_check'));
        expect(source, contains('subscription_cycles_renewal_lineage_check'));
      },
    );

    test('defines an immutable durable Finance outbox', () {
      final source = readAllMigrations();
      final events = tableBlock(
        source,
        'CREATE TABLE IF NOT EXISTS "finance"."events"',
      );

      expect(events, isNotEmpty);
      expect(events, contains('"event_sequence" bigserial'));
      expect(events, contains('"idempotency_key" text NOT NULL'));
      expect(events, contains('finance_events_idempotency_key_key'));
      expect(events, contains('finance_events_source_event_key'));
      expect(events, isNot(contains('"processed_at"')));
      expect(events, isNot(contains('"processing_error"')));

      expect(source, contains('finance_events_append_only'));
      expect(source, contains('finance_events_no_truncate'));
      expect(
        source,
        contains(
          'REVOKE ALL PRIVILEGES ON TABLE "finance"."events"\n'
          '    FROM PUBLIC, "anon", "authenticated", "service_role";',
        ),
      );
    });

    test('defines independent durable consumer inboxes', () {
      final source = readAllMigrations();

      expect(
        source,
        contains(
          'CREATE TABLE IF NOT EXISTS "system"."subscription_event_consumptions"',
        ),
      );
      expect(
        source,
        contains('CREATE TABLE IF NOT EXISTS "referrals"."event_consumptions"'),
      );
      expect(source, contains('event_consumptions_finance_event_id_key'));
      expect(
        source,
        contains('subscription_event_consumptions_finance_event_id_key'),
      );
      expect(source, contains('subscription_event_failures_append_only'));
      expect(source, contains('event_failures_append_only'));
      expect(source, contains('event_failures_no_truncate'));
    });

    test('enforces one referral and one reward per referred person', () {
      final source = readAllMigrations();

      expect(source, contains('referrals_referred_profile_id_key'));
      expect(
        source,
        contains(
          'CREATE UNIQUE INDEX IF NOT EXISTS "referrals_referred_profile_id_key"',
        ),
      );
      expect(
        source,
        contains('"rewards_referral_id_key" UNIQUE ("referral_id")'),
      );
      expect(source, contains('rewards_source_finance_event_id_key'));
      expect(source, contains('rewards_recovery_obligation_id_fkey'));
      expect(source, contains('referrals_distinct_profiles_check'));
    });

    test('encodes KSh 40 and KSh 500 minimum withdrawal exactly', () {
      final source = readAllMigrations();

      expect(
        source,
        contains('"reward_amount" numeric(20,4) NOT NULL DEFAULT 40'),
      );
      expect(
        source,
        contains('"minimum_withdrawal" numeric(20,4) NOT NULL DEFAULT 500'),
      );
      expect(
        source,
        contains(
          'program_settings_reward_amount_check" CHECK ("reward_amount" = 40)',
        ),
      );
      expect(
        source,
        contains(
          'program_settings_minimum_withdrawal_check" CHECK ("minimum_withdrawal" = 500)',
        ),
      );
      expect(source, contains('withdrawal_requests_amount_check'));
    });

    test('prevents duplicate and premature reward reservations', () {
      final source = readAllMigrations();

      expect(
        source,
        contains('CREATE TABLE IF NOT EXISTS "referrals"."withdrawal_items"'),
      );
      expect(source, contains('withdrawal_items_active_reward_key'));
      expect(source, contains("WHERE \"status\" = 'reserved'"));
      expect(
        source,
        contains('withdrawal_requests_one_open_per_beneficiary_key'),
      );
      expect(source, contains('withdrawal_requests_mpesa_receipt_key'));
      expect(source, contains('withdrawal_items_mutation_guard'));
      expect(source, contains('withdrawal_requests_status_guard'));
      expect(source, contains('withdrawal_requests_obligation_state_check'));
      expect(source, contains('withdrawal_requests_recipient_state_check'));
      expect(source, contains('recipient_verified_at'));
      expect(source, contains('Reward is not eligible for reservation'));
      expect(
        source,
        contains(
          'Withdrawal items can only be reserved while the request is requested',
        ),
      );
      expect(
        source,
        contains('Reward is already linked to a withdrawal request'),
      );
    });

    test('preserves reservation and payout history', () {
      final source = readAllMigrations();

      expect(source, contains('withdrawal_items_no_delete'));
      expect(source, contains('withdrawal_items_no_truncate'));
      expect(source, contains('withdrawal_items_release_reward'));
      expect(source, contains('withdrawal_requests_release_items'));
      expect(source, contains('withdrawal_requests_no_delete'));
      expect(source, contains('withdrawal_requests_no_truncate'));
      expect(source, contains('withdrawal_events_append_only'));
      expect(source, contains('withdrawal_events_no_truncate'));
      expect(source, contains('Invalid withdrawal item status transition'));
      expect(source, contains('Invalid withdrawal request status transition'));
    });

    test('keeps audit and reservation history append-only', () {
      final source = readAllMigrations();

      expect(source, contains('reject_append_only_mutation'));
      expect(source, contains('reject_delete_mutation'));
      expect(source, contains('reward_events_append_only'));
      expect(source, contains('audit_events_append_only'));
      expect(source, contains('withdrawal_events_append_only'));
      expect(source, contains('event_failures_append_only'));
      expect(source, contains('reward_events_no_truncate'));
      expect(source, contains('audit_events_no_truncate'));
      expect(source, contains('referrals_no_delete'));
      expect(source, contains('rewards_no_delete'));
      expect(source, contains('subscription_cycles_no_delete'));
      expect(source, contains('subscription_cycles_no_truncate'));
      expect(source, contains('reject_subscription_cycle_delete'));
      expect(source, contains('assisted_registrations_no_delete'));
      expect(source, contains('employee_exclusions_no_delete'));
    });

    test('does not create a second wallet or ledger in referrals', () {
      final source = readAllMigrations();

      expect(
        RegExp(
          r'CREATE TABLE IF NOT EXISTS "referrals"\."(wallet|ledger|journal)',
        ).hasMatch(source),
        isFalse,
      );
      expect(
        source,
        isNot(
          contains('CREATE TABLE IF NOT EXISTS "referrals"."ledger_accounts"'),
        ),
      );
    });

    test('keeps direct client table access closed', () {
      final source = readAllMigrations();

      expect(
        source,
        contains(
          'GRANT USAGE ON SCHEMA "referrals" TO "authenticated", "service_role";',
        ),
      );
      expect(
        source,
        contains(
          'REVOKE CREATE ON SCHEMA "referrals" FROM PUBLIC, "anon", "authenticated";',
        ),
      );

      for (final table in <String>[
        'program_settings',
        'attribution_sessions',
        'assisted_registrations',
        'employee_exclusions',
        'referrals',
        'rewards',
        'review_cases',
        'reward_events',
        'audit_events',
        'event_consumptions',
        'event_failures',
        'withdrawal_requests',
        'withdrawal_items',
        'withdrawal_events',
      ]) {
        expect(
          source,
          contains('REVOKE ALL PRIVILEGES ON TABLE "referrals"."$table"'),
          reason: 'Missing revoke for referrals.$table',
        );
      }

      expect(
        RegExp(r'GRANT\s+SELECT\s+ON\s+TABLE\s+"referrals"').hasMatch(source),
        isFalse,
      );
      expect(
        RegExp(r'GRANT\s+INSERT\s+ON\s+TABLE\s+"referrals"').hasMatch(source),
        isFalse,
      );
    });

    test('enables RLS on the new financial and referral tables', () {
      final source = readAllMigrations();

      for (final table in <String>[
        'finance.subscription_cycles',
        'finance.events',
        'system.subscription_event_consumptions',
        'system.subscription_event_failures',
        'referrals.referrals',
        'referrals.rewards',
        'referrals.event_consumptions',
        'referrals.withdrawal_requests',
        'referrals.withdrawal_items',
        'referrals.withdrawal_events',
      ]) {
        final quoted = table.replaceFirst('.', '"."');
        expect(
          source,
          contains('ALTER TABLE "$quoted" ENABLE ROW LEVEL SECURITY;'),
          reason: 'Missing RLS for $table',
        );
      }
    });
  });
}
