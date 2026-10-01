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
///
/// ❌ Does NOT:
///   - Contain UI or state
///   - Grant or check permissions (backend RLS is authoritative)
/// ============================================================
library;

import '../../domain/models/logistics_dashboard_models.dart';
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
}
