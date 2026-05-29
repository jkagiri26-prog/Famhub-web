import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../monitoring/dashboard_runtime_health_snapshot.dart';
import '../providers/dashboard_runtime_watchdog_provider.dart';
import '../providers/dashboard_frame_scheduler_provider.dart';

final dashboardHealthSnapshotProvider =
    Provider<DashboardRuntimeHealthSnapshot>((ref) {
  final watchdog = ref.watch(dashboardRuntimeWatchdogProvider);
  final scheduler = ref.watch(dashboardFrameSchedulerProvider);

  final lastMetrics = watchdog.lastMetrics;

  return DashboardRuntimeHealthSnapshot.fromMetrics(
    coalescerQueueSize: scheduler.queueSize,
    frameSchedulerBacklog: scheduler.backlog,

    /// ========================================================
    /// REAL SIGNAL ONLY (NO FABRICATED DEFAULTS)
    /// ========================================================
    lastPatchExecutionDuration: lastMetrics?.patchExecutionLatency,

    /// rollback removed → explicit null is correct
    lastRollbackAt: null,

    /// IMPORTANT: preserve truth, not assumptions
    activeZoneCount: null,
  );
});