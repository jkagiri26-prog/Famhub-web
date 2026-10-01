import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/features/logistics/application/providers/logistics_shipment_provider.dart';
import 'package:famhub_app/features/logistics/presentation/pages/logistics_shipment_detail_page.dart';
import 'package:famhub_app/features/logistics/presentation/pages/logistics_shipments_page.dart';

import 'logistics_test_harness.dart';

void main() {
  group('LogisticsShipmentsPage', () {
    testWidgets('renders a bounded list of shipment rows', (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipments = [
          shipmentFixture(id: 'ship-a', trackingNumber: 'TRK-42'),
          shipmentFixture(id: 'ship-b', trackingNumber: 'TRK-77'),
        ];

      await pumpTestApp(
        tester,
        const LogisticsShipmentsPage(),
        overrides: defaultOverrides(repository: repo),
      );

      expect(find.text('Shipments'), findsOneWidget);
      expect(find.text('2 shipments · tap for details'), findsOneWidget);
      expect(find.text('TRK-42'), findsOneWidget);
      expect(find.text('TRK-77'), findsOneWidget);
      expect(find.text('Molo Express'), findsNWidgets(2));
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
    });

    testWidgets('falls back to a short id when no tracking number exists',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipments = [
          shipmentFixture(
            id: '018f0000-0000-7000-8000-000000000099',
            trackingNumber: null,
          ),
        ];

      await pumpTestApp(
        tester,
        const LogisticsShipmentsPage(),
        overrides: defaultOverrides(repository: repo),
      );

      expect(find.textContaining('#'), findsWidgets);
      expect(find.text('Carrier not assigned'), findsNothing);
    });

    testWidgets('shows the empty state when the backend returns no rows',
        (tester) async {
      final repo = FakeLogisticsRepository()..shipments = const [];

      await pumpTestApp(
        tester,
        const LogisticsShipmentsPage(),
        overrides: defaultOverrides(repository: repo),
      );

      expect(find.text('No shipments yet'), findsOneWidget);
      expect(find.text('Loading shipments...'), findsNothing);
    });

    testWidgets('shows a retryable error state when the read fails',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..readError = Exception('connection reset');

      await pumpTestApp(
        tester,
        const LogisticsShipmentsPage(),
        overrides: defaultOverrides(repository: repo),
      );

      expect(find.text('Could not load your shipments.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      repo
        ..readError = null
        ..shipments = [shipmentFixture(trackingNumber: 'TRK-42')];

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('TRK-42'), findsOneWidget);
      expect(find.text('Could not load your shipments.'), findsNothing);
    });

    testWidgets('locks the list when the user has no shipment permission',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipments = [shipmentFixture()];

      await pumpTestApp(
        tester,
        const LogisticsShipmentsPage(),
        overrides: [
          ...defaultOverrides(repository: repo, allowedPermissions: const {}),
        ],
      );

      expect(find.text('Shipments locked'), findsOneWidget);
      expect(find.text('TRK-42'), findsNothing);
    });

    testWidgets('asks a guest to sign in without querying the backend',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipments = [shipmentFixture()];

      await pumpTestApp(
        tester,
        const LogisticsShipmentsPage(),
        overrides: defaultOverrides(
          repository: repo,
          context: const EntityContext(isGuest: true, isLoading: false),
        ),
      );

      expect(find.text('Shipments locked'), findsOneWidget);
      expect(
        find.text('Sign in to view shipments for your active entity.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a loading state while the read is in flight',
        (tester) async {
      final repo = GatedShipmentRepository();

      await pumpTestApp(
        tester,
        const LogisticsShipmentsPage(),
        overrides: defaultOverrides(repository: repo),
        settle: false,
      );

      expect(find.text('Loading shipments...'), findsOneWidget);
      expect(find.text('TRK-42'), findsNothing);

      repo.shipmentsGate.complete([shipmentFixture(trackingNumber: 'TRK-42')]);
      await tester.pumpAndSettle();

      expect(find.text('TRK-42'), findsOneWidget);
      expect(find.text('Loading shipments...'), findsNothing);
    });

    testWidgets('pushes the shipment detail page when a row is tapped',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipments = [
          shipmentFixture(
            id: '018f0000-0000-7000-8000-000000000001',
            trackingNumber: 'TRK-42',
          ),
        ]
        ..shipmentDetail = shipmentDetailFixture();

      await pumpTestApp(
        tester,
        const LogisticsShipmentsPage(),
        overrides: defaultOverrides(repository: repo),
      );

      await tester.tap(find.text('TRK-42'));
      await tester.pumpAndSettle();

      expect(find.byType(LogisticsShipmentDetailPage), findsOneWidget);
      expect(find.text('TRK-42'), findsWidgets);
    });
  });
}
