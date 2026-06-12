import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/monitoring/dashboard_runtime_health_snapshot.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/dashboard_runtime_watchdog_provider.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/dashboard_frame_scheduler_provider.dart';

final dashboardHealthSnapshotProvider =
    Provider<DashboardRuntimeHealthSnapshot>((ref) {
  final watchdog = ref.watch(dashboardRuntimeWatchdogProvider);
  final scheduler = ref.watch(dashboardFrameSchedulerProvider);

  final lastMetrics = watchdog.lastMetrics;

  return DashboardRuntimeHealthSnapshot.fromMetrics(
    coalescerQueueSize: scheduler.queueSize,
    frameSchedulerBacklog: scheduler.backlog,

    /// ========================================================
    /// REAL ENGINE SIGNALS ONLY
    /// ========================================================
    lastPatchExecutionDuration: lastMetrics?.patchExecutionLatency,

    /// rollback concept removed from runtime architecture
    lastRollbackAt: null,

    /// ========================================================
    /// ZONES ARE NOT A RUNTIME HEALTH METRIC ANYMORE
    /// (Composition layer responsibility only)
    /// ========================================================
    activeZoneCount: null,
  );
});