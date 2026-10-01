import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/features/logistics/config/permissions.dart';
import 'package:famhub_app/features/logistics/domain/models/logistics_dashboard_models.dart';
import 'package:famhub_app/features/logistics/domain/models/logistics_detail_models.dart';
import 'package:famhub_app/features/logistics/presentation/pages/logistics_shipment_detail_page.dart';
import 'package:famhub_app/features/logistics/presentation/widgets/logistics_assign_transport_dialog.dart';
import 'package:famhub_app/features/logistics/presentation/widgets/logistics_driver_tracking_controls_widget.dart';

import 'logistics_test_harness.dart';

void main() {
  group('LogisticsShipmentDetailPage', () {
    testWidgets('renders the single bounded detail payload', (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipmentDetail = shipmentDetailFixture();

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(shipmentId: '018f0000-0000-7000-8000-000000000001'),
        overrides: defaultOverrides(repository: repo),
      );

      expect(find.text('TRK-42'), findsWidgets);
      expect(find.text('IN TRANSIT'), findsOneWidget);

      expect(find.text('ITEMS'), findsOneWidget);
      expect(find.text('Tomatoes — Hybrid Seed'), findsOneWidget);
      expect(find.text('40 Kilogram (kg), 12.5 kg'), findsOneWidget);
      expect(find.text('Handle with care'), findsOneWidget);

      expect(find.text('ROUTE'), findsOneWidget);
      expect(find.text('1. Pickup · Nakuru Depot'), findsOneWidget);
      expect(find.text('2. Drop-off · Nairobi Market'), findsOneWidget);

      expect(find.text('TRANSPORT'), findsOneWidget);
      expect(find.text('Molo Freight Ltd'), findsOneWidget);
      expect(find.text('Jane Wanjiku · KDG 123A · Truck'), findsOneWidget);

      expect(find.text('TRACKING'), findsOneWidget);
      expect(
        find.byType(LogisticsDriverTrackingControlsWidget),
        findsOneWidget,
      );

      expect(find.text('RECENT EVENTS'), findsOneWidget);
      expect(find.text('Picked Up'), findsOneWidget);
    });

    testWidgets('shows the not-found state when the backend has no row',
        (tester) async {
      final repo = FakeLogisticsRepository()..shipmentDetail = null;

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(shipmentId: 'missing'),
        overrides: defaultOverrides(repository: repo),
      );

      expect(find.text('Shipment not available'), findsOneWidget);
    });

    testWidgets('shows a retryable error state when the read fails',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..readError = Exception('reset by peer');

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(shipmentId: 'ship-a'),
        overrides: defaultOverrides(repository: repo),
      );

      expect(find.text('Could not load this shipment.'), findsOneWidget);

      repo
        ..readError = null
        ..shipmentDetail = shipmentDetailFixture();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('TRK-42'), findsWidgets);
    });

    testWidgets('locks the detail when the user has no shipment permission',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipmentDetail = shipmentDetailFixture();

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(shipmentId: 'ship-a'),
        overrides: defaultOverrides(repository: repo, allowedPermissions: const {}),
      );

      expect(find.text('Shipment locked'), findsOneWidget);
      expect(find.byType(LogisticsDriverTrackingControlsWidget), findsNothing);
    });

    testWidgets('asks a guest to sign in', (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipmentDetail = shipmentDetailFixture();

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(shipmentId: 'ship-a'),
        overrides: defaultOverrides(
          repository: repo,
          context: const EntityContext(isGuest: true, isLoading: false),
        ),
      );

      expect(find.text('Shipment locked'), findsOneWidget);
      expect(find.text('Sign in to view this shipment.'), findsOneWidget);
    });

    testWidgets('hides tracking controls when no transport is assigned',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipmentDetail = const LogisticsShipmentDetail(
          shipment: _unassignedShipment,
        );

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(shipmentId: 'ship-a'),
        overrides: defaultOverrides(repository: repo),
      );

      expect(find.text('No transport assigned'), findsOneWidget);
      expect(find.byType(LogisticsDriverTrackingControlsWidget), findsNothing);
      expect(find.text('Tracking not started'), findsOneWidget);
    });

    testWidgets('hides the assign action when the role may not assign',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipmentDetail = const LogisticsShipmentDetail(
          shipment: _unassignedShipment,
        );

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(shipmentId: 'ship-a'),
        overrides: defaultOverrides(
          repository: repo,
          allowedPermissions: const {LogisticsPermissions.viewShipments},
        ),
      );

      expect(find.text('No transport assigned'), findsOneWidget);
      expect(find.text('Assign transport'), findsNothing);
      expect(
        find.text('Assigning transport is not enabled for your role.'),
        findsOneWidget,
      );
    });
  });

  group('assign_transport', () {
    testWidgets('submits the backend RPC with the entered administration input',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipmentDetail = shipmentDetailFixture();

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(
          shipmentId: '018f0000-0000-7000-8000-000000000001',
        ),
        overrides: defaultOverrides(repository: repo),
      );

      await tester.tap(find.text('Assign another carrier'));
      await tester.pumpAndSettle();

      expect(find.byType(LogisticsAssignTransportDialog), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Transport provider entity id *'),
        'prov-1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Driver profile id (optional)'),
        'driver-1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Vehicle id (optional)'),
        'veh-1',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Notes (optional)'),
        '  Call the gate  ',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(find.byType(LogisticsAssignTransportDialog), findsNothing);
      expect(repo.assignTransportCount, 1);
      expect(repo.assignTransportCalls.single, <String, dynamic>{
        'shipmentId': '018f0000-0000-7000-8000-000000000001',
        'providerEntityId': 'prov-1',
        'driverProfileId': 'driver-1',
        'vehicleId': 'veh-1',
        'notes': 'Call the gate',
      });
    });

    testWidgets('requires a provider before calling the backend',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipmentDetail = const LogisticsShipmentDetail(
          shipment: _unassignedShipment,
        );

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(shipmentId: 'ship-a'),
        overrides: defaultOverrides(repository: repo),
      );

      await tester.tap(find.text('Assign transport'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(repo.assignTransportCount, 0);
      expect(find.text('Select a transport provider.'), findsOneWidget);
      expect(find.byType(LogisticsAssignTransportDialog), findsOneWidget);
    });

    testWidgets('surfaces a backend rejection without leaking the RPC name',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipmentDetail = const LogisticsShipmentDetail(
          shipment: _unassignedShipment,
        )
        ..actionError = permissionDeniedRpc('logistics.assign_transport');

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(shipmentId: 'ship-a'),
        overrides: defaultOverrides(repository: repo),
      );

      await tester.tap(find.text('Assign transport'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Transport provider entity id *'),
        'prov-1',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(
        find.text("You don't have permission to assign transport "
            'for this shipment.'),
        findsOneWidget,
      );
      expect(find.textContaining('assign_transport'), findsNothing);
      expect(find.textContaining('42501'), findsNothing);
      expect(find.text('Assign'), findsOneWidget);
      expect(repo.assignTransportCount, 0);
    });

    testWidgets('offers a dropdown when backend candidates are available',
        (tester) async {
      final repo = FakeLogisticsRepository()
        ..shipmentDetail = const LogisticsShipmentDetail(
          shipment: _unassignedShipment,
        )
        ..transportOptions = const LogisticsTransportOptions(
          providers: [LogisticsProviderOption(id: 'prov-1', name: 'Molo Freight Ltd')],
          drivers: [LogisticsDriverOption(id: 'driver-1', name: 'Jane Wanjiku')],
          vehicles: [
            LogisticsVehicleOption(
              id: 'veh-1',
              registrationRef: 'KDG 123A',
              vehicleType: 'Truck',
            ),
          ],
        );

      await pumpTestApp(
        tester,
        const LogisticsShipmentDetailPage(shipmentId: 'ship-a'),
        overrides: defaultOverrides(repository: repo),
      );

      await tester.tap(find.text('Assign transport'));
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
      expect(
        find.widgetWithText(TextField, 'Transport provider entity id *'),
        findsNothing,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(find.text('Select a transport provider.'), findsOneWidget);
      expect(repo.assignTransportCount, 0);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Molo Freight Ltd').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign'));
      await tester.pumpAndSettle();

      expect(find.byType(LogisticsAssignTransportDialog), findsNothing);
      expect(repo.assignTransportCount, 1);
      expect(
        repo.assignTransportCalls.single['providerEntityId'],
        'prov-1',
      );
      expect(repo.assignTransportCalls.single['driverProfileId'], isNull);
      expect(repo.assignTransportCalls.single['vehicleId'], isNull);
      expect(repo.assignTransportCalls.single['notes'], '');
    });
  });
}

const LogisticsShipment _unassignedShipment = LogisticsShipment(
  id: 'ship-a',
  status: 'draft',
  updatedAt: null,
);
