import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level contract checks for billing-account creation, invoice-number
/// allocation, and the annual-purchase KES invariant.
void main() {
  final directory = Directory('supabase/migrations');

  String migration(String name) =>
      File('${directory.path}/$name').readAsStringSync();

  group('Billing dependency contract', () {
    test('self-scoped individual billing account function exists', () {
      final source = migration(
        '20261112000010_individual_billing_accounts.sql',
      );

      expect(source, contains('system"."ensure_individual_billing_account'));
      expect(source, contains('auth.uid()'));
      expect(source, contains('core.ensure_entity_for_profile'));
      expect(source, contains("'individual'"));
      expect(source, contains("'KES'"));
      expect(source, contains("'active'"));
      expect(
        source,
        contains(
          'ON CONFLICT ON CONSTRAINT "uq_billing_account_entity_profile"',
        ),
      );
      expect(source, contains('pg_advisory_xact_lock'));
      expect(source, contains('TO "authenticated"'));
      expect(source, isNot(contains('p_profile_id')));
      expect(source, isNot(contains('p_entity_id')));
      expect(source, isNot(contains("'business'")));
      expect(source, isNot(contains("'cooperative'")));
      expect(source, isNot(contains("'supplier'")));
    });

    test('invoice-number allocator is sequence-based and server-only', () {
      final source = migration('20261112000011_invoice_number_sequence.sql');

      expect(source, contains('CREATE SEQUENCE IF NOT EXISTS'));
      expect(source, contains('system"."invoice_number_seq'));
      expect(source, contains('system"."allocate_invoice_number'));
      expect(source, contains('nextval'));
      expect(source, contains('TO "service_role"'));
      expect(source, isNot(contains("'INV-'")));
      expect(source, isNot(contains('random()')));
    });

    test('annual purchase enforces KES billing account currency', () {
      final source = migration(
        '20261112000009_annual_subscription_purchase.sql',
      );

      expect(source, contains("v_account.currency <> 'KES'"));
      expect(source, contains("v_plan.currency <> 'KES'"));
      expect(source, contains("v_plan.billing_cycle <> 'yearly'"));
      expect(source, contains('v_plan.amount <= 0'));
      expect(source, contains("v_account.status <> 'active'"));
      expect(source, contains("v_account.account_type <> 'individual'"));
      expect(source, contains('v_entity.owner_id <> v_account.profile_id'));
    });
  });
}
