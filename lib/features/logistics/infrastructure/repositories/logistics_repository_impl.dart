/// ============================================================
/// LOGISTICS REPOSITORY IMPL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/infrastructure/repositories/
///     = concrete repository
///
/// ✅ Responsibilities:
///   - Compose the bounded data-source reads into one dashboard
///     snapshot.
///   - Run the independent reads concurrently.
///   - Delegate every write to the confirmed backend RPC contract.
///
/// ❌ Does NOT:
///   - Contain UI or state
///   - Grant or check permissions (backend RLS is authoritative)
/// ============================================================
library;

import '../../domain/models/logistics_dashboard_models.dart';
import '../../domain/models/logistics_detail_models.dart';
import '../../domain/repositories/logistics_repository.dart';
import '../data_sources/logistics_remote_data_source.dart';

class LogisticsRepositoryImpl implements LogisticsRepository {
  final LogisticsRemoteDataSource _dataSource;

  LogisticsRepositoryImpl({LogisticsRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? LogisticsRemoteDataSource();

  @override
  Future<LogisticsDashboardSnapshot> fetchDashboard({String? entityId}) async {
    // Independent bounded reads — issued together, awaited together so a
    // failure in one read never leaves another future unhandled.
    final results = await Future.wait<List<dynamic>>([
      _dataSource.fetchActiveShipments(entityId: entityId),
      _dataSource.fetchRecentShipments(entityId: entityId),
      _dataSource.fetchAssignments(),
      _dataSource.fetchActiveTrackingSessions(entityId: entityId),
    ]);

    final activeShipments =
        results[0].cast<LogisticsShipment>().toList(growable: false);
    final recentShipments =
        results[1].cast<LogisticsShipment>().toList(growable: false);
    final assignments =
        results[2].cast<LogisticsAssignment>().toList(growable: false);
    final activeTrackingSessions =
        results[3].cast<LogisticsTrackingSession>().toList(growable: false);

    final isTruncated =
        LogisticsRemoteDataSource.hitBound(
              activeShipments.length,
              LogisticsRemoteDataSource.activeShipmentLimit,
            ) ||
            LogisticsRemoteDataSource.hitBound(
              recentShipments.length,
              LogisticsRemoteDataSource.recentShipmentLimit,
            ) ||
            LogisticsRemoteDataSource.hitBound(
              assignments.length,
              LogisticsRemoteDataSource.assignmentLimit,
            ) ||
            LogisticsRemoteDataSource.hitBound(
              activeTrackingSessions.length,
              LogisticsRemoteDataSource.trackingSessionLimit,
            );

    return LogisticsDashboardSnapshot(
      activeShipments: activeShipments,
      recentShipments: recentShipments,
      assignments: assignments,
      activeTrackingSessions: activeTrackingSessions,
      isTruncated: isTruncated,
    );
  }

  @override
  Future<List<LogisticsShipment>> fetchShipments({
    String? entityId,
    int limit = LogisticsRemoteDataSource.shipmentListLimit,
  }) {
    return _dataSource.fetchShipments(entityId: entityId, limit: limit);
  }

  @override
  Future<LogisticsShipmentDetail?> fetchShipmentDetail(
    String shipmentId, {
    String? entityId,
  }) {
    return _dataSource.fetchShipmentDetail(shipmentId, entityId: entityId);
  }

  @override
  Future<LogisticsTransportOptions> fetchTransportOptions({String? entityId}) {
    return _dataSource.fetchTransportOptions(entityId: entityId);
  }

  @override
  Future<LogisticsTrackingSession?> fetchLatestTrackingSession(
    String assignmentId,
  ) {
    return _dataSource.fetchLatestTrackingSession(assignmentId);
  }

  @override
  Future<List<LogisticsTrackingSession>> fetchTrackingSessions({
    String? entityId,
    int limit = LogisticsRemoteDataSource.sessionPickerLimit,
  }) {
    return _dataSource.fetchTrackingSessions(entityId: entityId, limit: limit);
  }

  @override
  Future<LogisticsTrackingSessionDetail?> fetchTrackingSessionDetail(
    String trackingSessionId, {
    int pointLimit = LogisticsRemoteDataSource.locationPointLimit,
  }) {
    return _dataSource.fetchTrackingSessionDetail(
      trackingSessionId,
      pointLimit: pointLimit,
    );
  }

  // ── Backend RPC actions ─────────────────────────────────────

  @override
  Future<String> startTrackingSession({required String assignmentId}) {
    return _dataSource.startTrackingSession(assignmentId: assignmentId);
  }

  @override
  Future<String> pauseTrackingSession({required String trackingSessionId}) {
    return _dataSource.pauseTrackingSession(trackingSessionId: trackingSessionId);
  }

  @override
  Future<String> resumeTrackingSession({required String trackingSessionId}) {
    return _dataSource.resumeTrackingSession(trackingSessionId: trackingSessionId);
  }

  @override
  Future<String> completeTrackingSession({required String trackingSessionId}) {
    return _dataSource
        .completeTrackingSession(trackingSessionId: trackingSessionId);
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
  }) {
    return _dataSource.recordLocationPoint(
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

  @override
  Future<String> assignTransport({
    required String shipmentId,
    required String providerEntityId,
    String? driverProfileId,
    String? vehicleId,
    String? notes,
  }) {
    return _dataSource.assignTransport(
      shipmentId: shipmentId,
      providerEntityId: providerEntityId,
      driverProfileId: driverProfileId,
      vehicleId: vehicleId,
      notes: notes,
    );
  }
}
