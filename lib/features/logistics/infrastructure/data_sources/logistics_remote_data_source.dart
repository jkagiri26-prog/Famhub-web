/// ============================================================
/// LOGISTICS REMOTE DATA SOURCE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/infrastructure/data_sources/
///     = Supabase access for the logistics module
///
/// ✅ Responsibilities:
///   - Bounded reads against `logistics.*` (and best-effort label
///     lookups against `core.*` / `users.*`).
///   - Select only the columns the UI renders.
///   - Route every write through the backend RPC gateway.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Authorization stays with backend RLS — no ownership is
///     derived or injected by the client.
///   - The optional `entityId` only narrows a query using the
///     active entity already resolved by the context mechanism.
///   - No direct UPDATE/INSERT: tracking lifecycle and GPS points
///     go through confirmed RPCs only.
///
/// ❌ Does NOT:
///   - Run raw SQL
///   - Poll or subscribe
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/logistics_dashboard_models.dart';
import '../../domain/models/logistics_detail_models.dart';
import 'logistics_rpc_gateway.dart';

/// Remote data source for Logistics reads and RPC-backed actions.
class LogisticsRemoteDataSource {
  final SupabaseClient _client;
  final LogisticsRpcGateway _rpc;

  LogisticsRemoteDataSource({SupabaseClient? client, LogisticsRpcGateway? rpc})
      : _client = client ?? Supabase.instance.client,
        _rpc = rpc ?? SupabaseLogisticsRpcGateway(client: client);

  // ── Bounds (low-data requirement) ──────────────────────────
  static const int activeShipmentLimit = 6;
  static const int recentShipmentLimit = 6;
  static const int assignmentLimit = 8;
  static const int trackingSessionLimit = 4;

  static const int shipmentListLimit = 30;
  static const int shipmentItemCountLimit = 50;
  static const int stopLimit = 30;
  static const int shipmentAssignmentLimit = 6;
  static const int shipmentSessionLimit = 6;
  static const int eventLimit = 20;
  static const int sessionPickerLimit = 10;
  static const int locationPointLimit = 50;

  static const int providerOptionLimit = 20;
  static const int driverOptionLimit = 15;
  static const int vehicleOptionLimit = 15;

  // ── Explicit column selections (low-data requirement) ──────
  static const String _shipmentColumns =
      'id, status, tracking_number, carrier, updated_at';
  static const String _assignmentColumns =
      'id, shipment_id, status, assigned_at, accepted_at';
  static const String _trackingSessionColumns =
      'id, shipment_id, status, started_at, last_location_captured_at';
  static const String _trackingSessionDetailColumns =
      'id, shipment_id, assignment_id, status, started_at, ended_at, '
      'last_location_captured_at, entity_id';
  static const String _shipmentItemColumns =
      'id, shipment_id, item_id, variant_id, unit_id, quantity, weight, '
      'package_count, notes, created_at';
  static const String _stopColumns =
      'id, shipment_id, sequence_number, stop_type, location_id, status, '
      'scheduled_arrival, actual_arrival, scheduled_departure, '
      'actual_departure, notes';
  static const String _assignmentDetailColumns =
      'id, shipment_id, provider_entity_id, driver_profile_id, vehicle_id, '
      'status, assigned_at, accepted_at, started_at, completed_at, notes';
  static const String _eventColumns =
      'id, shipment_id, event_type, occurred_at, notes';
  static const String _locationPointColumns =
      'id, tracking_session_id, captured_at, received_at, latitude, '
      'longitude, accuracy, speed, heading, altitude';

  /// In-flight shipment statuses.
  static const List<String> _activeShipmentStatuses =
      LogisticsShipmentStatus.active;

  // ── Shipment reads ─────────────────────────────────────────

  Future<List<LogisticsShipment>> fetchActiveShipments({
    String? entityId,
    int limit = activeShipmentLimit,
  }) async {
    var query = _client
        .schema('logistics')
        .from('shipments')
        .select(_shipmentColumns);
    if (entityId != null) {
      query = query.eq('entity_id', entityId);
    }
    final rows = await query
        .inFilter('status', _activeShipmentStatuses)
        .order('updated_at', ascending: false)
        .limit(limit);
    return rows.map(LogisticsShipment.fromMap).toList();
  }

  Future<List<LogisticsShipment>> fetchRecentShipments({
    String? entityId,
    int limit = recentShipmentLimit,
  }) async {
    var query = _client
        .schema('logistics')
        .from('shipments')
        .select(_shipmentColumns);
    if (entityId != null) {
      query = query.eq('entity_id', entityId);
    }
    final rows =
        await query.order('updated_at', ascending: false).limit(limit);
    return rows.map(LogisticsShipment.fromMap).toList();
  }

  Future<List<LogisticsShipment>> fetchShipments({
    String? entityId,
    int limit = shipmentListLimit,
  }) async {
    var query = _client
        .schema('logistics')
        .from('shipments')
        .select(_shipmentColumns);
    if (entityId != null) {
      query = query.eq('entity_id', entityId);
    }
    final rows =
        await query.order('updated_at', ascending: false).limit(limit);
    return rows.map(LogisticsShipment.fromMap).toList();
  }

  Future<LogisticsShipmentDetail?> fetchShipmentDetail(
    String shipmentId, {
    String? entityId,
  }) async {
    var query = _client
        .schema('logistics')
        .from('shipments')
        .select(_shipmentColumns);
    if (entityId != null) {
      query = query.eq('entity_id', entityId);
    }
    final rows = await query.eq('id', shipmentId).limit(1);
    if (rows.isEmpty) return null;

    final shipment = LogisticsShipment.fromMap(rows.first);

    // Independent bounded reads — issued together so a failure in one
    // never leaves another future unhandled.
    final results = await Future.wait<Object?>([
      _fetchShipmentItems(shipmentId),
      _fetchStops(shipmentId),
      _fetchAssignmentsForShipment(shipmentId),
      _fetchSessionsForShipment(shipmentId),
      _fetchEvents(shipmentId),
    ]);

    final items = (results[0] as List<LogisticsShipmentItem>? ?? const []);
    final stops = (results[1] as List<LogisticsStop>? ?? const []);
    final assignments =
        (results[2] as List<LogisticsAssignment>? ?? const []);
    final sessions =
        (results[3] as List<LogisticsTrackingSession>? ?? const []);
    final events = (results[4] as List<LogisticsTrackingEvent>? ?? const []);

    return LogisticsShipmentDetail(
      shipment: shipment,
      items: items,
      stops: stops,
      assignments: assignments,
      trackingSessions: sessions,
      events: events,
      isTruncated:
          items.length >= shipmentItemCountLimit ||
          stops.length >= stopLimit ||
          assignments.length >= shipmentAssignmentLimit ||
          sessions.length >= shipmentSessionLimit ||
          events.length >= eventLimit,
    );
  }

  Future<List<LogisticsShipmentItem>> _fetchShipmentItems(
    String shipmentId,
  ) async {
    final rows = await _client
        .schema('logistics')
        .from('shipment_items')
        .select(_shipmentItemColumns)
        .eq('shipment_id', shipmentId)
        .order('created_at', ascending: true)
        .limit(shipmentItemCountLimit);
    if (rows.isEmpty) return const [];

    final items = rows.map(LogisticsShipmentItem.fromMap).toList();
    return _resolveItemLabels(items);
  }

  Future<List<LogisticsStop>> _fetchStops(String shipmentId) async {
    final rows = await _client
        .schema('logistics')
        .from('stops')
        .select(_stopColumns)
        .eq('shipment_id', shipmentId)
        .order('sequence_number', ascending: true)
        .limit(stopLimit);
    if (rows.isEmpty) return const [];

    final stops = rows.map(LogisticsStop.fromMap).toList();
    final locations = await _resolveById(
      schema: 'core',
      table: 'locations',
      ids: stops.map((stop) => stop.locationId).whereType<String>().toSet(),
    );
    return [
      for (final stop in stops)
        stop.withLocationName(locations[stop.locationId]),
    ];
  }

  Future<List<LogisticsAssignment>> _fetchAssignmentsForShipment(
    String shipmentId,
  ) async {
    final rows = await _client
        .schema('logistics')
        .from('assignments')
        .select(_assignmentDetailColumns)
        .eq('shipment_id', shipmentId)
        .order('assigned_at', ascending: false)
        .limit(shipmentAssignmentLimit);
    if (rows.isEmpty) return const [];

    final assignments = rows.map(LogisticsAssignment.fromMap).toList();
    return _resolveAssignmentLabels(assignments);
  }

  Future<List<LogisticsTrackingSession>> _fetchSessionsForShipment(
    String shipmentId,
  ) async {
    final rows = await _client
        .schema('logistics')
        .from('tracking_sessions')
        .select(_trackingSessionDetailColumns)
        .eq('shipment_id', shipmentId)
        .order('started_at', ascending: false)
        .limit(shipmentSessionLimit);
    return rows.map(LogisticsTrackingSession.fromMap).toList();
  }

  Future<List<LogisticsTrackingEvent>> _fetchEvents(
    String shipmentId,
  ) async {
    final rows = await _client
        .schema('logistics')
        .from('tracking_events')
        .select(_eventColumns)
        .eq('shipment_id', shipmentId)
        .order('occurred_at', ascending: false)
        .limit(eventLimit);
    return rows.map(LogisticsTrackingEvent.fromMap).toList();
  }

  // ── Assignment reads ───────────────────────────────────────

  /// `logistics.assignments` has no entity column — scoping is RLS.
  Future<List<LogisticsAssignment>> fetchAssignments({
    int limit = assignmentLimit,
  }) async {
    final rows = await _client
        .schema('logistics')
        .from('assignments')
        .select(_assignmentColumns)
        .order('assigned_at', ascending: false)
        .limit(limit);
    return rows.map(LogisticsAssignment.fromMap).toList();
  }

  // ── Tracking reads ─────────────────────────────────────────

  Future<List<LogisticsTrackingSession>> fetchActiveTrackingSessions({
    String? entityId,
    int limit = trackingSessionLimit,
  }) async {
    var query = _client
        .schema('logistics')
        .from('tracking_sessions')
        .select(_trackingSessionColumns)
        .eq('status', LogisticsTrackingStatus.active);
    if (entityId != null) {
      query = query.eq('entity_id', entityId);
    }
    final rows =
        await query.order('started_at', ascending: false).limit(limit);
    return rows.map(LogisticsTrackingSession.fromMap).toList();
  }

  Future<LogisticsTrackingSession?> fetchLatestTrackingSession(
    String assignmentId,
  ) async {
    final rows = await _client
        .schema('logistics')
        .from('tracking_sessions')
        .select(_trackingSessionDetailColumns)
        .eq('assignment_id', assignmentId)
        .order('started_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return LogisticsTrackingSession.fromMap(rows.first);
  }

  Future<List<LogisticsTrackingSession>> fetchTrackingSessions({
    String? entityId,
    int limit = sessionPickerLimit,
  }) async {
    var query = _client
        .schema('logistics')
        .from('tracking_sessions')
        .select(_trackingSessionDetailColumns);
    if (entityId != null) {
      query = query.eq('entity_id', entityId);
    }
    final rows =
        await query.order('started_at', ascending: false).limit(limit);
    return rows.map(LogisticsTrackingSession.fromMap).toList();
  }

  Future<LogisticsTrackingSessionDetail?> fetchTrackingSessionDetail(
    String trackingSessionId, {
    int pointLimit = locationPointLimit,
  }) async {
    final sessionRows = await _client
        .schema('logistics')
        .from('tracking_sessions')
        .select(_trackingSessionDetailColumns)
        .eq('id', trackingSessionId)
        .limit(1);
    if (sessionRows.isEmpty) return null;

    final session = LogisticsTrackingSession.fromMap(sessionRows.first);
    final pointRows = await _client
        .schema('logistics')
        .from('location_points')
        .select(_locationPointColumns)
        .eq('tracking_session_id', trackingSessionId)
        .order('captured_at', ascending: false)
        .limit(pointLimit);

    return LogisticsTrackingSessionDetail(
      session: session,
      points: pointRows.map(LogisticsLocationPoint.fromMap).toList(),
      isTruncated: pointRows.length >= pointLimit,
    );
  }

  // ── Transport administration options ───────────────────────

  Future<LogisticsTransportOptions> fetchTransportOptions({
    String? entityId,
  }) async {
    final results = await Future.wait<Object?>([
      _fetchProviders(),
      _fetchDrivers(entityId),
      _fetchVehicles(),
    ]);

    return LogisticsTransportOptions(
      providers: results[0] as List<LogisticsProviderOption>? ?? const [],
      drivers: results[1] as List<LogisticsDriverOption>? ?? const [],
      vehicles: results[2] as List<LogisticsVehicleOption>? ?? const [],
    );
  }

  Future<List<LogisticsProviderOption>> _fetchProviders() async {
    try {
      final rows = await _client
          .schema('core')
          .from('entities')
          .select('id, name')
          .eq('is_active', true)
          .inFilter('entity_type', const [
            'service_provider',
            'trading_company',
            'cooperative',
            'agrovet',
          ])
          .order('name', ascending: true)
          .limit(providerOptionLimit);
      return [
        for (final row in rows)
          if (row['id'] != null && row['name'] != null)
            LogisticsProviderOption(
              id: row['id'].toString(),
              name: row['name'].toString(),
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<LogisticsDriverOption>> _fetchDrivers(String? entityId) async {
    if (entityId == null) return const [];
    try {
      final memberRows = await _client
          .schema('core')
          .from('entity_members')
          .select('profile_id')
          .eq('entity_id', entityId)
          .eq('is_active', true)
          .limit(driverOptionLimit);
      final profileIds = memberRows
          .map((row) => row['profile_id']?.toString())
          .whereType<String>()
          .toList();
      if (profileIds.isEmpty) return const [];

      final profileRows = await _client
          .schema('users')
          .from('profiles')
          .select('id, first_name, last_name')
          .inFilter('id', profileIds)
          .limit(driverOptionLimit);
      return [
        for (final row in profileRows)
          if (row['id'] != null)
            LogisticsDriverOption(
              id: row['id'].toString(),
              name: _profileName(row),
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<LogisticsVehicleOption>> _fetchVehicles() async {
    try {
      final rows = await _client
          .schema('logistics')
          .from('vehicles')
          .select('id, registration_ref, vehicle_type')
          .eq('is_active', true)
          .order('registration_ref', ascending: true)
          .limit(vehicleOptionLimit);
      return [
        for (final row in rows)
          if (row['id'] != null && row['registration_ref'] != null)
            LogisticsVehicleOption(
              id: row['id'].toString(),
              registrationRef: row['registration_ref'].toString(),
              vehicleType: row['vehicle_type']?.toString() ?? '',
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  // ── Best-effort label resolution ───────────────────────────
  //
  // Related rows (items, variants, units, locations, entities, profiles,
  // vehicles) may not be readable for every role. A denied lookup simply
  // yields an empty map and the UI falls back to ids — it never fails the
  // whole detail read.

  Future<List<LogisticsShipmentItem>> _resolveItemLabels(
    List<LogisticsShipmentItem> items,
  ) async {
    final itemIds =
        items.map((item) => item.itemId).whereType<String>().toSet();
    final variantIds =
        items.map((item) => item.variantId).whereType<String>().toSet();
    final unitIds =
        items.map((item) => item.unitId).whereType<String>().toSet();

    final results = await Future.wait<Object?>([
      _resolveById(schema: 'core', table: 'items', ids: itemIds),
      _resolveById(schema: 'core', table: 'item_variants', ids: variantIds),
      _resolveById(
        schema: 'core',
        table: 'units',
        ids: unitIds,
        select: 'id, name, symbol',
        labelOf: (row) {
          final name = row['name']?.toString() ?? '';
          final symbol = row['symbol']?.toString() ?? '';
          if (symbol.isEmpty || name.isEmpty) return name;
          return '$name ($symbol)';
        },
      ),
    ]);

    final itemNames = results[0] as Map<String, String>;
    final variantNames = results[1] as Map<String, String>;
    final unitNames = results[2] as Map<String, String>;

    return [
      for (final item in items)
        item.withResolvedNames(
          itemName: itemNames[item.itemId],
          variantName: variantNames[item.variantId],
          unitName: unitNames[item.unitId],
        ),
    ];
  }

  Future<List<LogisticsAssignment>> _resolveAssignmentLabels(
    List<LogisticsAssignment> assignments,
  ) async {
    final providerIds =
        assignments.map((a) => a.providerEntityId).whereType<String>().toSet();
    final driverIds =
        assignments.map((a) => a.driverProfileId).whereType<String>().toSet();
    final vehicleIds =
        assignments.map((a) => a.vehicleId).whereType<String>().toSet();

    final results = await Future.wait<Object?>([
      _resolveById(schema: 'core', table: 'entities', ids: providerIds),
      _resolveById(
        schema: 'users',
        table: 'profiles',
        ids: driverIds,
        select: 'id, first_name, last_name',
        labelOf: _profileName,
      ),
      _resolveById(
        schema: 'logistics',
        table: 'vehicles',
        ids: vehicleIds,
        select: 'id, registration_ref, vehicle_type',
        labelOf: (row) {
          final reg = row['registration_ref']?.toString() ?? '';
          final type = row['vehicle_type']?.toString() ?? '';
          if (reg.isEmpty) return '';
          return type.isEmpty ? reg : '$reg · $type';
        },
      ),
    ]);

    final providerNames = results[0] as Map<String, String>;
    final driverNames = results[1] as Map<String, String>;
    final vehicleLabels = results[2] as Map<String, String>;

    return [
      for (final assignment in assignments)
        assignment.withResolvedNames(
          providerName: providerNames[assignment.providerEntityId],
          driverName: driverNames[assignment.driverProfileId],
          vehicleLabel: vehicleLabels[assignment.vehicleId],
        ),
    ];
  }

  Future<Map<String, String>> _resolveById({
    required String schema,
    required String table,
    required Set<String> ids,
    String select = 'id, name',
    String Function(Map<String, dynamic> row)? labelOf,
  }) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .schema(schema)
          .from(table)
          .select(select)
          .inFilter('id', ids.toList())
          .limit(ids.length + 8);
      if (rows.isEmpty) return const {};

      final resolved = <String, String>{};
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null) continue;
        final label = (labelOf ?? _defaultLabel)(row).trim();
        if (label.isNotEmpty) resolved[id] = label;
      }
      return resolved;
    } catch (_) {
      return const {};
    }
  }

  // ── Backend RPC actions (writes) ───────────────────────────

  Future<String> startTrackingSession({required String assignmentId}) =>
      _rpc.startTrackingSession(assignmentId: assignmentId);

  Future<String> pauseTrackingSession({required String trackingSessionId}) =>
      _rpc.pauseTrackingSession(trackingSessionId: trackingSessionId);

  Future<String> resumeTrackingSession({required String trackingSessionId}) =>
      _rpc.resumeTrackingSession(trackingSessionId: trackingSessionId);

  Future<String> completeTrackingSession({required String trackingSessionId}) =>
      _rpc.completeTrackingSession(trackingSessionId: trackingSessionId);

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
  }) {
    return _rpc.recordLocationPoint(
      trackingSessionId: trackingSessionId,
      idempotencyKey: idempotencyKey,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      speed: speed,
      heading: heading,
      altitude: altitude,
    );
  }

  Future<String> assignTransport({
    required String shipmentId,
    required String providerEntityId,
    String? driverProfileId,
    String? vehicleId,
    String? notes,
  }) {
    return _rpc.assignTransport(
      shipmentId: shipmentId,
      providerEntityId: providerEntityId,
      driverProfileId: driverProfileId,
      vehicleId: vehicleId,
      notes: notes,
    );
  }

  /// True when any bounded list hit its limit — the UI then
  /// knows more data exists without downloading it.
  static bool hitBound(int length, int bound) => length >= bound;

  static String _profileName(Map<String, dynamic> row) {
    final first = row['first_name']?.toString().trim() ?? '';
    final last = row['last_name']?.toString().trim() ?? '';
    final name = '$first $last'.trim();
    if (name.isNotEmpty) return name;
    return row['email']?.toString() ?? '';
  }

  static String _defaultLabel(Map<String, dynamic> row) {
    return row['name']?.toString() ?? '';
  }
}
