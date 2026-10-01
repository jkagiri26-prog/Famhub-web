/// ============================================================
/// LOGISTICS REMOTE DATA SOURCE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/infrastructure/data_sources/
///     = Supabase access for the logistics module
///
/// ✅ Responsibilities:
///   - Bounded reads against `logistics.*` tables.
///   - Select only the columns the dashboard renders.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Authorization stays with backend RLS — no ownership is
///     derived or injected by the client.
///   - The optional `entityId` only narrows a query using the
///     active entity already resolved by the context mechanism.
///
/// ❌ Does NOT:
///   - Write data
///   - Run raw SQL
///   - Poll or subscribe
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/logistics_dashboard_models.dart';

/// Remote data source for Logistics dashboard reads.
class LogisticsRemoteDataSource {
  final SupabaseClient _client;

  LogisticsRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ── Bounds (low-data requirement) ──────────────────────────
  static const int activeShipmentLimit = 6;
  static const int recentShipmentLimit = 6;
  static const int assignmentLimit = 8;
  static const int trackingSessionLimit = 4;

  static const String _shipmentColumns =
      'id, status, tracking_number, carrier, updated_at';
  static const String _assignmentColumns =
      'id, shipment_id, status, assigned_at, accepted_at';
  static const String _trackingSessionColumns =
      'id, shipment_id, status, started_at, last_location_captured_at';

  /// In-flight shipment statuses.
  static const List<String> _activeShipmentStatuses =
      LogisticsShipmentStatus.active;

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

  /// True when any bounded list hit its limit — the dashboard then
  /// knows more data exists without downloading it.
  static bool hitBound(int length, int bound) => length >= bound;
}
