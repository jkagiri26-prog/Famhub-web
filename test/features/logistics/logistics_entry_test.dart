import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/composition/router/dynamic_route_registrar.dart';
import 'package:famhub_app/features/logistics/domain/models/logistics_dashboard_models.dart';
import 'package:famhub_app/system/registry/module_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Logistics entry route', () {
    setUp(() {
      bootstrapModulePageBuilders();
    });

    test('page builder is registered for the logistics module', () {
      expect(ModulePageRegistry.hasBuilder('logistics'), isTrue);
      expect(ModulePageRegistry.resolve('logistics'), isNotNull);
    });

    test('module registry entry route stays /logistics', () {
      final definition = ModuleRegistry.byId('logistics');
      expect(definition, isNotNull);
      expect(definition!.entryRoute, '/logistics');
      expect(definition.moduleId, 'logistics');
    });
  });

  group('Logistics shipment read model', () {
    test('maps a bounded shipments row', () {
      final shipment = LogisticsShipment.fromMap(const {
        'id': '018f0000-0000-7000-8000-000000000001',
        'status': 'in_transit',
        'tracking_number': 'TRK-42',
        'carrier': 'Molo Express',
        'updated_at': '2026-03-12T14:05:00+00:00',
      });

      expect(shipment.status, 'in_transit');
      expect(shipment.isActive, isTrue);
      expect(shipment.statusLabel, 'In Transit');
      expect(shipment.trackingNumber, 'TRK-42');
      expect(shipment.carrier, 'Molo Express');
      expect(shipment.updatedAt, isNotNull);
    });

    test('treats delivered shipments as inactive', () {
      final shipment = LogisticsShipment.fromMap(const {
        'id': 'abc',
        'status': 'delivered',
      });
      expect(shipment.isActive, isFalse);
    });

    test('tolerates missing optional columns', () {
      final shipment = LogisticsShipment.fromMap(const {'status': 'draft'});
      expect(shipment.id, isEmpty);
      expect(shipment.trackingNumber, isNull);
      expect(shipment.updatedAt, isNull);
    });
  });

  group('Logistics assignment read model', () {
    test('an assignment is pending only before acceptance', () {
      final pending = LogisticsAssignment.fromMap(const {
        'id': 'a1',
        'shipment_id': 's1',
        'status': 'assigned',
        'assigned_at': '2026-03-12T10:00:00+00:00',
      });
      expect(pending.isPending, isTrue);
      expect(pending.isActive, isTrue);

      final accepted = LogisticsAssignment.fromMap(const {
        'id': 'a2',
        'shipment_id': 's2',
        'status': 'accepted',
        'accepted_at': '2026-03-12T11:00:00+00:00',
      });
      expect(accepted.isPending, isFalse);
      expect(accepted.isActive, isTrue);
    });
  });

  group('Logistics dashboard snapshot', () {
    test('aggregates active, pending and tracking availability', () {
      const activeShipment = LogisticsShipment(
        id: 's1',
        status: 'picked_up',
      );
      const pendingAssignment = LogisticsAssignment(
        id: 'a1',
        shipmentId: 's1',
        status: 'assigned',
      );
      const activeSession = LogisticsTrackingSession(
        id: 't1',
        shipmentId: 's1',
        status: 'active',
        lastLocationCapturedAt: null,
      );

      const snapshot = LogisticsDashboardSnapshot(
        activeShipments: [activeShipment],
        recentShipments: [activeShipment],
        assignments: [pendingAssignment],
        activeTrackingSessions: [activeSession],
      );

      expect(snapshot.isEmpty, isFalse);
      expect(snapshot.activeAssignments, hasLength(1));
      expect(snapshot.pendingAssignments, hasLength(1));
      expect(snapshot.hasActiveTracking, isTrue);
      expect(snapshot.trackingAvailable, isTrue);
      expect(snapshot.latestTrackingCapture, isNull);
    });

    test('reports an empty dashboard without throwing', () {
      expect(LogisticsDashboardSnapshot.empty.isEmpty, isTrue);
      expect(LogisticsDashboardSnapshot.empty.hasActiveTracking, isFalse);
      expect(LogisticsDashboardSnapshot.empty.trackingAvailable, isFalse);
    });

    test('picks the most recent tracking capture', () {
      const older = LogisticsTrackingSession(
        id: 't1',
        shipmentId: 's1',
        status: 'active',
        lastLocationCapturedAt: null,
      );
      final newer = LogisticsTrackingSession.fromMap(const {
        'id': 't2',
        'shipment_id': 's2',
        'status': 'active',
        'last_location_captured_at': '2026-03-12T15:30:00+00:00',
      });

      final snapshot = LogisticsDashboardSnapshot(
        activeTrackingSessions: [older, newer],
      );

      expect(
        snapshot.latestTrackingCapture?.toUtc().toString(),
        '2026-03-12 15:30:00.000Z',
      );
    });
  });
}
