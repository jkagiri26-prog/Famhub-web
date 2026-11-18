import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/subscription/domain/models/subscription_entitlements.dart';

Map<String, dynamic> _row({
  bool active = false,
  bool future = false,
  bool expired = false,
  String billingCycle = 'monthly',
  String start = '2026-01-31T21:00:00Z',
  String end = '2026-02-28T21:00:00Z',
  List<String> capabilities = const [],
}) {
  return {
    'entity_id': 'entity-1',
    'billing_owner_type': 'individual',
    'plan_name': 'Test Plan',
    'billing_cycle': billingCycle,
    'start_date': start,
    'end_date': end,
    'is_active': active,
    'is_future': future,
    'is_expired': expired,
    'capabilities': capabilities,
  };
}

void main() {
  group('SubscriptionEntitlements', () {
    test('active monthly subscription grants backend capabilities', () {
      final result = SubscriptionEntitlements.fromRows([
        _row(
          active: true,
          capabilities: ['farm.management', 'marketplace.listings'],
        ),
      ]);

      expect(result.verified, isTrue);
      expect(result.isActive, isTrue);
      expect(result.billingCycle, 'monthly');
      expect(result.allowsModule('farm.management'), isTrue);
      expect(result.allowsModule('marketplace.listings'), isTrue);
      expect(result.allowsModule('logistics'), isFalse);
    });

    test('expired subscription grants no paid capabilities', () {
      final result = SubscriptionEntitlements.fromRows([
        _row(
          expired: true,
          billingCycle: 'quarterly',
          capabilities: ['farm.management'],
        ),
      ]);

      expect(result.isExpired, isTrue);
      expect(result.allowsModule('farm.management'), isFalse);
      expect(result.capabilities, isEmpty);
    });

    test('future subscription does not activate early', () {
      final result = SubscriptionEntitlements.fromRows([
        _row(
          future: true,
          start: '2027-01-01T00:00:00Z',
          capabilities: ['farm.management'],
        ),
      ]);

      expect(result.isFuture, isTrue);
      expect(result.allowsModule('farm.management'), isFalse);
    });

    test('supports wildcard namespaces without plan-specific Flutter maps', () {
      final result = SubscriptionEntitlements.fromRows([
        _row(active: true, capabilities: ['farm.*', 'trader.listings']),
      ]);

      expect(result.hasCapability('farm.management'), isTrue);
      expect(result.hasCapability('farm.livestock'), isTrue);
      expect(result.hasCapability('trader.listings'), isTrue);
      expect(result.hasCapability('trader.orders'), isFalse);
    });

    test('annual cycle uses its own stored boundaries', () {
      final result = SubscriptionEntitlements.fromRows([
        _row(
          active: true,
          billingCycle: 'yearly',
          start: '2026-12-31T21:00:00Z',
          end: '2027-12-31T21:00:00Z',
          capabilities: ['farm.management'],
        ),
      ]);

      expect(result.isActive, isTrue);
      expect(result.billingCycle, 'yearly');
      expect(result.startDate, DateTime.utc(2026, 12, 31, 21));
      expect(result.endDate, DateTime.utc(2027, 12, 31, 21));
      expect(result.allowsModule('farm_management'), isTrue);
    });

    test('renewal uses the active period and ignores future capabilities', () {
      final result = SubscriptionEntitlements.fromRows([
        _row(
          future: true,
          start: '2027-01-01T00:00:00Z',
          end: '2028-01-01T00:00:00Z',
          capabilities: ['trader.*'],
        ),
        _row(
          active: true,
          start: '2026-01-01T00:00:00Z',
          end: '2027-01-01T00:00:00Z',
          capabilities: ['farm.*'],
        ),
      ]);

      expect(result.isActive, isTrue);
      expect(result.hasCapability('farm.management'), isTrue);
      expect(result.hasCapability('trader.listings'), isFalse);
    });

    test('no active subscription grants no paid capabilities', () {
      expect(SubscriptionEntitlements.empty.allowsModule('farm'), isFalse);
      expect(SubscriptionEntitlements.unverified.allowsModule('farm'), isFalse);
    });

    test('Nairobi boundary timestamps remain UTC instants from backend', () {
      final result = SubscriptionEntitlements.fromRows([
        _row(
          active: true,
          start: '2026-01-31T21:00:00Z',
          end: '2026-02-28T21:00:00Z',
          capabilities: ['farm.management'],
        ),
      ]);

      expect(result.startDate, DateTime.utc(2026, 1, 31, 21));
      expect(result.endDate, DateTime.utc(2026, 2, 28, 21));
      expect(result.startDate!.isUtc, isTrue);
      expect(result.endDate!.isUtc, isTrue);
    });
  });

  group('Canonical resolver contract', () {
    final migration = File(
      'supabase/migrations/20261116000004_subscription_entitlement_resolver.sql',
    ).readAsStringSync();

    test('resolver uses actual subscription timestamps and exclusive end', () {
      expect(migration, contains('active.start_date <= now()'));
      expect(migration, contains('now() < active.end_date'));
      expect(migration, contains('active.start_date > now()'));
      expect(migration, contains('active.end_date <= now()'));
      expect(migration, isNot(contains("interval '1 year'")));
    });

    test('resolver only grants capabilities from active confirmed cycles', () {
      expect(migration, contains("cycle.status = 'active'"));
      expect(migration, contains("active.status = 'active'"));
      expect(migration, contains('THEN ARRAY(SELECT system.plan_capabilities'));
      expect(migration, contains('ELSE ARRAY[]::text[]'));
    });

    test('capability source is canonical plan metadata', () {
      expect(migration, contains('features_json'));
      expect(migration, contains('system"."plan_capabilities'));
      expect(migration, contains("p_features->'capabilities'"));
      expect(migration, contains("p_features->'features'"));
      expect(migration, isNot(contains("'farm.management'")));
      expect(migration, isNot(contains("'trader.orders'")));
    });

    test('entity and individual ownership are enforced server-side', () {
      expect(migration, contains('auth.uid()'));
      expect(migration, contains('core.get_active_entity()'));
      expect(migration, contains('core.entity_members'));
      expect(migration, contains('can_manage IS TRUE'));
      expect(
        migration,
        contains('Caller cannot access this entity subscription'),
      );
      expect(migration, contains('TO "authenticated"'));
      expect(migration, isNot(contains('TO "service_role"')));
    });

    test('billing cycle comes from plan data, not an annual assumption', () {
      expect(migration, contains('plan.billing_cycle'));
      expect(migration, contains('billing_cycle'));
      expect(migration, isNot(contains('annual_sequence')));
      expect(migration, isNot(contains('interval \'1 month\'')));
      expect(migration, isNot(contains('interval \'3 months\'')));
    });
  });
}
