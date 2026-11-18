import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/subscription/application/providers/subscription_entitlements_provider.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_entitlements.dart';
import 'package:famhub_app/core/subscription/presentation/widgets/premium_capability_gate.dart';

Map<String, dynamic> _row({
  bool active = false,
  bool expired = false,
  List<String> capabilities = const [],
}) {
  return {
    'entity_id': 'entity-1',
    'billing_owner_type': 'individual',
    'plan_name': 'Future Premium Plan',
    'billing_cycle': 'monthly',
    'start_date': '2026-01-01T00:00:00Z',
    'end_date': '2026-02-01T00:00:00Z',
    'is_active': active,
    'is_future': false,
    'is_expired': expired,
    'capabilities': capabilities,
  };
}

Widget _app({
  SubscriptionEntitlements? entitlements,
  Future<SubscriptionEntitlements>? pending,
  Future<SubscriptionEntitlements>? error,
}) {
  return ProviderScope(
    overrides: [
      if (error != null)
        subscriptionEntitlementsProvider.overrideWith((ref) => error)
      else if (pending != null)
        subscriptionEntitlementsProvider.overrideWith((ref) => pending)
      else
        subscriptionEntitlementsProvider.overrideWith(
          (ref) async => entitlements ?? SubscriptionEntitlements.empty,
        ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: PremiumCapabilityGate(
          capabilityKey: 'future.premium',
          title: 'Future premium feature',
          child: Text('premium-child'),
        ),
      ),
    ),
  );
}

void main() {
  group('PremiumCapabilityGate foundation', () {
    testWidgets('capability present allows the premium child', (tester) async {
      await tester.pumpWidget(
        _app(
          entitlements: SubscriptionEntitlements.fromRows([
            _row(active: true, capabilities: ['future.premium']),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('premium-child'), findsOneWidget);
      expect(find.text('Future premium feature'), findsNothing);
    });

    testWidgets('capability absent denies the premium child', (tester) async {
      await tester.pumpWidget(
        _app(
          entitlements: SubscriptionEntitlements.fromRows([
            _row(active: true, capabilities: ['unrelated.capability']),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('Future premium feature'), findsOneWidget);
      expect(find.text('premium-child'), findsNothing);
      expect(find.text('View subscription plans'), findsOneWidget);
    });

    testWidgets('entitlement loading fails closed', (tester) async {
      final completer = Completer<SubscriptionEntitlements>();
      await tester.pumpWidget(_app(pending: completer.future));
      await tester.pump();

      expect(find.text('Future premium feature'), findsOneWidget);
      expect(find.text('premium-child'), findsNothing);
    });

    testWidgets('entitlement error fails closed', (tester) async {
      final completer = Completer<SubscriptionEntitlements>();
      await tester.pumpWidget(_app(pending: completer.future));
      await tester.pump();

      completer.completeError(Exception('down'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Future premium feature'), findsOneWidget);
      expect(find.text('premium-child'), findsNothing);
    });

    testWidgets('expired subscription denies the premium child', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          entitlements: SubscriptionEntitlements.fromRows([
            _row(expired: true, capabilities: ['future.premium']),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('Future premium feature'), findsOneWidget);
      expect(find.text('premium-child'), findsNothing);
    });

    testWidgets('active subscription grants the premium child', (tester) async {
      await tester.pumpWidget(
        _app(
          entitlements: SubscriptionEntitlements.fromRows([
            _row(active: true, capabilities: ['future.premium']),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('premium-child'), findsOneWidget);
    });
  });

  group('Premium capability foundation contract', () {
    final migration = File(
      'supabase/migrations/20261116000007_premium_capability_assertion.sql',
    ).readAsStringSync();
    final docs = File(
      'docs/subscription/premium_capability_contract.md',
    ).readAsStringSync();
    final farmGate = File(
      'lib/features/farm_management/presentation/widgets/premium/farm_premium_insights_gate.dart',
    ).readAsStringSync();

    test('server assertion reuses the canonical resolver', () {
      expect(migration, contains('has_subscription_capability'));
      expect(migration, contains('assert_subscription_capability'));
      expect(migration, contains('resolve_my_subscription_entitlements'));
      expect(migration, contains('entitlement.is_active IS TRUE'));
      expect(
        migration,
        contains('v_capability = ANY (entitlement.capabilities)'),
      );
      expect(migration, isNot(contains('CREATE TABLE')));
      expect(migration, isNot(contains('TO "service_role"')));
    });

    test('server assertion requires authentication and exact capability', () {
      expect(migration, contains('auth.uid() IS NULL'));
      expect(migration, contains("USING ERRCODE = '42501'"));
      expect(migration, contains('lower(btrim(coalesce(p_capability'));
    });

    test('farm_analytics remains the reference capability', () {
      expect(farmGate, contains("'farm_analytics'"));
      expect(farmGate, contains('PremiumCapabilityGate'));
      expect(farmGate, isNot(contains('farm.management')));
      expect(docs, contains('farm_analytics'));
      expect(docs, contains('subscriptionEntitlementsProvider'));
      expect(docs, contains('PremiumCapabilityGate'));
    });
  });
}
