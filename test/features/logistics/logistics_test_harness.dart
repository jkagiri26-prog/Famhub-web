import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/context_engine/controllers/context_controller.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/providers/connectivity_provider.dart';
import 'package:famhub_app/features/logistics/application/providers/logistics_dashboard_provider.dart';
import 'package:famhub_app/features/logistics/application/providers/logistics_permission_provider.dart';
import 'package:famhub_app/features/logistics/application/services/device_location_source.dart';
import 'package:famhub_app/features/logistics/domain/models/logistics_dashboard_models.dart';
import 'package:famhub_app/features/logistics/domain/models/logistics_detail_models.dart';
import 'package:famhub_app/features/logistics/domain/repositories/logistics_repository.dart';

/// ============================================================
/// LOGISTICS TEST HARNESS
///
/// Hand-written fakes (no mocking package) for the Logistics feature.
/// ============================================================

const EntityContext signedInContext = EntityContext(
  userId: 'user-1',
  profileId: 'profile-1',
  entityId: 'entity-1',
  roleId: 'role-1',
  isGuest: false,
  isLoading: false,
);

/// Replaces the real context engine with a fixed, signed-in context.
Override contextOverride({EntityContext context = signedInContext}) {
  return contextProvider.overrideWith(() => _FixedContextController(context));
}

class _FixedContextController extends ContextController {
  _FixedContextController(this.context);

  final EntityContext context;

  @override
  EntityContext build() => context;
}

/// Grants every Logistics permission the backend check returns true for.
Override allowAllPermissions() =>
    logisticsPermissionCheckerProvider.overrideWithValue((key) async => true);

/// Grants only [allowed] Logistics permission keys.
Override allowOnlyPermissions(Set<String> allowed) {
  return logisticsPermissionCheckerProvider.overrideWithValue(
    (key) async => allowed.contains(key),
  );
}

/// Grants no Logistics permission keys.
Override denyAllPermissions() =>
    logisticsPermissionCheckerProvider.overrideWithValue((key) async => false);

/// Keeps `connectivity_plus` off the platform channel in tests.
Override connectivityOverride() {
  return connectivityProvider.overrideWith((ref) => const Stream<bool>.empty());
}

List<Override> defaultOverrides({
  required LogisticsRepository repository,
  DeviceLocationSource? deviceLocationSource,
  EntityContext context = signedInContext,
  Set<String>? allowedPermissions,
}) {
  return [
    logisticsRepositoryProvider.overrideWithValue(repository),
    contextOverride(context: context),
    connectivityOverride(),
    if (deviceLocationSource != null)
      deviceLocationSourceProvider.overrideWithValue(deviceLocationSource),
    if (allowedPermissions != null)
      allowOnlyPermissions(allowedPermissions)
    else
      allowAllPermissions(),
  ];
}

Future<void> pumpTestApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
  bool settle = true,
}) async {
  // Detail pages are long ListViews; give them room so every section is
  // actually built instead of being lazily skipped off-screen.
  tester.view.physicalSize = const Size(1200, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Lets already-scheduled microtasks/futures run without real time passing.
Future<void> settle([int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// ── Fake repository ────────────────────────────────────────────

class FakeLogisticsRepository implements LogisticsRepository {
  // ── Read payloads ──
  LogisticsDashboardSnapshot dashboard = LogisticsDashboardSnapshot.empty;
  List<LogisticsShipment> shipments = const [];
  LogisticsShipmentDetail? shipmentDetail;
  LogisticsTransportOptions transportOptions = LogisticsTransportOptions.empty;
  LogisticsTrackingSession? latestTrackingSession;
  List<LogisticsTrackingSession> trackingSessions = const [];
  LogisticsTrackingSessionDetail? trackingSessionDetail;

  Object? readError;

  // ── Action behavior ──
  /// Thrown by every action (simulates a backend rejection).
  Object? actionError;

  /// When set, [startTrackingSession] waits on it before returning.
  Completer<void>? startGate;

  /// Number of upcoming `record_location_point` calls that should fail.
  int locationFailures = 0;

  /// Thrown by failing `record_location_point` calls.
  Object locationFailureError = const PostgrestException(
    message: 'network unreachable',
  );

  // ── Recorded actions ──
  int startCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int completeCount = 0;
  int recordLocationCount = 0;
  int assignTransportCount = 0;

  final List<String> startAssignmentIds = <String>[];
  final List<String> pauseSessionIds = <String>[];
  final List<String> resumeSessionIds = <String>[];
  final List<String> completeSessionIds = <String>[];
  final List<Map<String, dynamic>> recordLocationCalls = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> assignTransportCalls = <Map<String, dynamic>>[];

  void _throwIfFailing() {
    final error = actionError;
    if (error != null) throw error;
  }

  @override
  Future<LogisticsDashboardSnapshot> fetchDashboard({String? entityId}) async {
    if (readError != null) throw readError!;
    return dashboard;
  }

  @override
  Future<List<LogisticsShipment>> fetchShipments({
    String? entityId,
    int limit = 30,
  }) async {
    if (readError != null) throw readError!;
    return shipments;
  }

  @override
  Future<LogisticsShipmentDetail?> fetchShipmentDetail(
    String shipmentId, {
    String? entityId,
  }) async {
    if (readError != null) throw readError!;
    return shipmentDetail;
  }

  @override
  Future<LogisticsTransportOptions> fetchTransportOptions({
    String? entityId,
  }) async {
    if (readError != null) throw readError!;
    return transportOptions;
  }

  @override
  Future<LogisticsTrackingSession?> fetchLatestTrackingSession(
    String assignmentId,
  ) async {
    if (readError != null) throw readError!;
    return latestTrackingSession;
  }

  @override
  Future<List<LogisticsTrackingSession>> fetchTrackingSessions({
    String? entityId,
    int limit = 10,
  }) async {
    if (readError != null) throw readError!;
    return trackingSessions;
  }

  @override
  Future<LogisticsTrackingSessionDetail?> fetchTrackingSessionDetail(
    String trackingSessionId, {
    int pointLimit = 50,
  }) async {
    if (readError != null) throw readError!;
    return trackingSessionDetail;
  }

  @override
  Future<String> startTrackingSession({required String assignmentId}) async {
    final gate = startGate;
    if (gate != null) await gate.future;
    _throwIfFailing();
    startCount++;
    startAssignmentIds.add(assignmentId);
    return 'session-$startCount';
  }

  @override
  Future<String> pauseTrackingSession({
    required String trackingSessionId,
  }) async {
    _throwIfFailing();
    pauseCount++;
    pauseSessionIds.add(trackingSessionId);
    return trackingSessionId;
  }

  @override
  Future<String> resumeTrackingSession({
    required String trackingSessionId,
  }) async {
    _throwIfFailing();
    resumeCount++;
    resumeSessionIds.add(trackingSessionId);
    return trackingSessionId;
  }

  @override
  Future<String> completeTrackingSession({
    required String trackingSessionId,
  }) async {
    _throwIfFailing();
    completeCount++;
    completeSessionIds.add(trackingSessionId);
    return trackingSessionId;
  }

  @override
  Future<String> recordLocationPoint({
    required String trackingSessionId,
    required String idempotencyKey,
    required DateTime capturedAt,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
    double? altitude,
  }) async {
    if (locationFailures > 0) {
      locationFailures--;
      recordLocationCount++;
      recordLocationCalls.add(<String, dynamic>{
        'trackingSessionId': trackingSessionId,
        'idempotencyKey': idempotencyKey,
        'capturedAt': capturedAt,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'altitude': altitude,
      });
      throw locationFailureError;
    }
    _throwIfFailing();
    recordLocationCount++;
    recordLocationCalls.add(<String, dynamic>{
      'trackingSessionId': trackingSessionId,
      'idempotencyKey': idempotencyKey,
      'capturedAt': capturedAt,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
      'altitude': altitude,
    });
    return 'point-$recordLocationCount';
  }

  @override
  Future<String> assignTransport({
    required String shipmentId,
    required String providerEntityId,
    String? driverProfileId,
    String? vehicleId,
    String? notes,
  }) async {
    _throwIfFailing();
    assignTransportCount++;
    assignTransportCalls.add(<String, dynamic>{
      'shipmentId': shipmentId,
      'providerEntityId': providerEntityId,
      'driverProfileId': driverProfileId,
      'vehicleId': vehicleId,
      'notes': notes,
    });
    return 'assignment-$assignTransportCount';
  }
}

// ── Gated read (loading-state tests) ───────────────────────────

class GatedShipmentRepository extends FakeLogisticsRepository {
  final Completer<List<LogisticsShipment>> shipmentsGate =
      Completer<List<LogisticsShipment>>();

  @override
  Future<List<LogisticsShipment>> fetchShipments({
    String? entityId,
    int limit = 30,
  }) async {
    if (readError != null) throw readError!;
    return shipmentsGate.future;
  }
}

// ── Fake device location ───────────────────────────────────────

class FakeDeviceLocationSource implements DeviceLocationSource {
  DeviceLocationState permissionState = DeviceLocationState.granted;
  int permissionRequests = 0;
  int watchRequests = 0;

  final StreamController<DeviceLocationSample> _controller =
      StreamController<DeviceLocationSample>.broadcast();

  @override
  Future<DeviceLocationState> ensurePermission() async {
    permissionRequests++;
    return permissionState;
  }

  @override
  Stream<DeviceLocationSample> watch() {
    watchRequests++;
    return _controller.stream;
  }

  void emit(DeviceLocationSample sample) => _controller.add(sample);

  Future<void> close() => _controller.close();
}

// ── Reusable fixtures ──────────────────────────────────────────

LogisticsShipment shipmentFixture({
  String id = '018f0000-0000-7000-8000-000000000001',
  String status = 'in_transit',
  String? trackingNumber = 'TRK-42',
  String? carrier = 'Molo Express',
  String updatedAt = '2026-03-12T14:05:00+00:00',
}) {
  return LogisticsShipment.fromMap(<String, dynamic>{
    'id': id,
    'status': status,
    'tracking_number': trackingNumber,
    'carrier': carrier,
    'updated_at': updatedAt,
  });
}

LogisticsShipmentDetail shipmentDetailFixture() {
  final shipment = shipmentFixture();

  final items = [
    LogisticsShipmentItem.fromMap(const {
      'id': 'item-1',
      'shipment_id': 's1',
      'item_id': 'i1',
      'variant_id': 'v1',
      'unit_id': 'u1',
      'quantity': 40,
      'weight': 12.5,
      'package_count': 4,
      'notes': 'Handle with care',
      'created_at': '2026-03-12T09:00:00+00:00',
    }).withResolvedNames(
      itemName: 'Tomatoes',
      variantName: 'Hybrid Seed',
      unitName: 'Kilogram (kg)',
    ),
  ];

  final stops = [
    LogisticsStop.fromMap(const {
      'id': 'stop-1',
      'shipment_id': 's1',
      'sequence_number': 1,
      'stop_type': 'pickup',
      'location_id': 'loc-1',
      'status': 'departed',
      'scheduled_arrival': '2026-03-12T08:00:00+00:00',
      'actual_arrival': '2026-03-12T08:10:00+00:00',
    }).withLocationName('Nakuru Depot'),
    LogisticsStop.fromMap(const {
      'id': 'stop-2',
      'shipment_id': 's1',
      'sequence_number': 2,
      'stop_type': 'dropoff',
      'location_id': 'loc-2',
      'status': 'planned',
      'scheduled_arrival': '2026-03-13T10:00:00+00:00',
    }).withLocationName('Nairobi Market'),
  ];

  final assignments = [
    LogisticsAssignment.fromMap(const {
      'id': 'assign-1',
      'shipment_id': 's1',
      'provider_entity_id': 'prov-1',
      'driver_profile_id': 'driver-1',
      'vehicle_id': 'veh-1',
      'status': 'accepted',
      'assigned_at': '2026-03-12T07:00:00+00:00',
      'accepted_at': '2026-03-12T07:15:00+00:00',
      'notes': 'Morning run',
    }).withResolvedNames(
      providerName: 'Molo Freight Ltd',
      driverName: 'Jane Wanjiku',
      vehicleLabel: 'KDG 123A · Truck',
    ),
  ];

  final sessions = [
    LogisticsTrackingSession.fromMap(const {
      'id': 'sess-1',
      'shipment_id': 's1',
      'assignment_id': 'assign-1',
      'status': 'active',
      'started_at': '2026-03-12T09:30:00+00:00',
      'last_location_captured_at': '2026-03-12T14:00:00+00:00',
    }),
  ];

  final events = [
    LogisticsTrackingEvent.fromMap(const {
      'id': 'evt-1',
      'shipment_id': 's1',
      'event_type': 'picked_up',
      'occurred_at': '2026-03-12T08:30:00+00:00',
    }),
    LogisticsTrackingEvent.fromMap(const {
      'id': 'evt-2',
      'shipment_id': 's1',
      'event_type': 'in_transit',
      'occurred_at': '2026-03-12T14:05:00+00:00',
    }),
  ];

  return LogisticsShipmentDetail(
    shipment: shipment,
    items: items,
    stops: stops,
    assignments: assignments,
    trackingSessions: sessions,
    events: events,
  );
}

DeviceLocationSample sampleFixture({
  DateTime? capturedAt,
  double latitude = -1.2921,
  double longitude = 36.8219,
}) {
  return DeviceLocationSample(
    capturedAt: capturedAt ?? DateTime.parse('2026-03-12T10:00:00Z'),
    latitude: latitude,
    longitude: longitude,
    accuracy: 5,
    speed: 8.5,
    heading: 90,
    altitude: 1700,
  );
}

/// Convenience for asserting a `PostgrestException` is a permission failure.
PostgrestException permissionDeniedRpc(String rpcName) {
  return PostgrestException(
    message: 'permission denied for function $rpcName',
    code: '42501',
  );
}
