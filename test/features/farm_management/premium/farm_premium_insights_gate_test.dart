import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/subscription/application/providers/subscription_entitlements_provider.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_entitlements.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/premium/farm_premium_insights_gate.dart';

final _entitlementsStateProvider =
    NotifierProvider<_EntitlementsNotifier, SubscriptionEntitlements>(
      _EntitlementsNotifier.new,
    );

class _EntitlementsNotifier extends Notifier<SubscriptionEntitlements> {
  @override
  SubscriptionEntitlements build() => SubscriptionEntitlements.empty;

  void set(SubscriptionEntitlements value) => state = value;
}

Map<String, dynamic> _row({
  bool active = false,
  bool expired = false,
  List<String> capabilities = const [],
}) {
  return {
    'entity_id': 'entity-1',
    'billing_owner_type': 'individual',
    'plan_name': 'Farm Plan',
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
  SubscriptionEntitlements? fixedEntitlements,
  Future<SubscriptionEntitlements>? pending,
  bool useMutableProvider = false,
}) {
  return ProviderScope(
    overrides: [
      if (useMutableProvider)
        subscriptionEntitlementsProvider.overrideWith(
          (ref) async => ref.watch(_entitlementsStateProvider),
        )
      else if (pending != null)
        subscriptionEntitlementsProvider.overrideWith((ref) => pending)
      else
        subscriptionEntitlementsProvider.overrideWith(
          (ref) async => fixedEntitlements ?? SubscriptionEntitlements.empty,
        ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: FarmPremiumInsightsGate(child: Text('premium-insights-child')),
      ),
    ),
  );
}

void main() {
  group('Farm premium insights gate', () {
    testWidgets('locks premium insights without entitlement', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();

      expect(find.text('Advanced farm insights'), findsOneWidget);
      expect(find.text('premium-insights-child'), findsNothing);
    });

    testWidgets('fails closed while entitlements are loading', (tester) async {
      final completer = Completer<SubscriptionEntitlements>();
      await tester.pumpWidget(_app(pending: completer.future));
      await tester.pump();

      expect(find.text('Advanced farm insights'), findsOneWidget);
      expect(find.text('premium-insights-child'), findsNothing);
    });

    testWidgets('active capability unlocks premium insights', (tester) async {
      await tester.pumpWidget(
        _app(
          fixedEntitlements: SubscriptionEntitlements.fromRows([
            _row(active: true, capabilities: [kFarmPremiumInsightsCapability]),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('premium-insights-child'), findsOneWidget);
      expect(find.text('Advanced farm insights'), findsNothing);
    });

    testWidgets('missing capability fails closed', (tester) async {
      await tester.pumpWidget(
        _app(
          fixedEntitlements: SubscriptionEntitlements.fromRows([
            _row(active: true, capabilities: ['marketplace.listings']),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('Advanced farm insights'), findsOneWidget);
      expect(find.text('premium-insights-child'), findsNothing);
    });

    testWidgets('expired subscription does not grant premium insights', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          fixedEntitlements: SubscriptionEntitlements.fromRows([
            _row(expired: true, capabilities: [kFarmPremiumInsightsCapability]),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('Advanced farm insights'), findsOneWidget);
      expect(find.text('premium-insights-child'), findsNothing);
    });

    testWidgets('pending or failed purchase does not grant insights', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          fixedEntitlements: SubscriptionEntitlements.fromRows([
            _row(active: false),
          ]),
        ),
      );
      await tester.pump();

      expect(find.text('Advanced farm insights'), findsOneWidget);
    });

    testWidgets('activation refresh unlocks and expiry refresh locks', (
      tester,
    ) async {
      await tester.pumpWidget(_app(useMutableProvider: true));
      await tester.pump();
      expect(find.text('premium-insights-child'), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FarmPremiumInsightsGate)),
      );
      container
          .read(_entitlementsStateProvider.notifier)
          .state = SubscriptionEntitlements.fromRows([
        _row(active: true, capabilities: [kFarmPremiumInsightsCapability]),
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.text('premium-insights-child'), findsOneWidget);

      container
          .read(_entitlementsStateProvider.notifier)
          .state = SubscriptionEntitlements.fromRows([
        _row(expired: true, capabilities: [kFarmPremiumInsightsCapability]),
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.text('premium-insights-child'), findsNothing);
      expect(find.text('Advanced farm insights'), findsOneWidget);
    });

    test('core Farm Management files remain outside the premium gate', () {
      final freeFiles = [
        'lib/features/farm_management/presentation/pages/farm_management_page.dart',
        'lib/features/farm_management/presentation/pages/farm_dashboard_page.dart',
        'lib/features/farm_management/presentation/pages/farms_page.dart',
        'lib/features/farm_management/presentation/pages/fields_page.dart',
        'lib/features/farm_management/presentation/pages/crops_page.dart',
        'lib/features/farm_management/presentation/pages/livestock_page.dart',
        'lib/features/farm_management/presentation/pages/activities_page.dart',
        'lib/features/farm_management/presentation/pages/add_farm_page.dart',
      ];
      for (final path in freeFiles) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          isNot(contains('FarmPremiumInsightsGate')),
          reason: path,
        );
        expect(
          source,
          isNot(contains('subscriptionEntitlementsProvider')),
          reason: path,
        );
      }
    });

    test('capability identifier is the existing Farm premium feature key', () {
      final registry = File(
        'lib/system/registry/feature_registry.dart',
      ).readAsStringSync();
      expect(registry, contains("featureKey: 'farm_analytics'"));
      expect(registry, contains('Advanced farm analytics and insights'));
      expect(kFarmPremiumInsightsCapability, 'farm_analytics');
      expect(kFarmPremiumInsightsCapability, isNot('farm.management'));
    });
  });
}
