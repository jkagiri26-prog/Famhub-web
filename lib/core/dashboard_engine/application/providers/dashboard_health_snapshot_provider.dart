import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/monitoring/dashboard_runtime_health_snapshot.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/dashboard_runtime_watchdog_provider.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/dashboard_frame_scheduler_provider.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/observability_providers.dart';

final dashboardHealthSnapshotProvider =
    Provider<DashboardRuntimeHealthSnapshot>((ref) {
  final watchdog = ref.watch(dashboardRuntimeWatchdogProvider);
  final scheduler = ref.watch(dashboardFrameSchedulerProvider);
  final resilience = ref.watch(resilienceMetricsProvider);
  final moduleMetrics = ref.watch(moduleMetricsProvider);

  final lastMetrics = watchdog.lastMetrics;

  // Count module health states
  int healthyCount = 0, degradedCount = 0, criticalCount = 0;
  for (final m in moduleMetrics.values) {
    if (m.healthIndex >= 0.8) {
      healthyCount++;
    } else if (m.healthIndex >= 0.5) {
      degradedCount++;
    } else {
      criticalCount++;
    }
  }

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
    totalFailures: resilience.totalFailures,
    totalRecoveries: resilience.totalRecoveries,
    recoveryRate: resilience.recoveryRate,
    currentStreak: resilience.currentStreak,
    maxStreak: resilience.maxStreak,
    consecutiveFailures: resilience.consecutiveFailures,
    mtbfMinutes: resilience.mtbfMinutes,
    mttrSeconds: resilience.mttrSeconds,
    moduleCount: moduleMetrics.length,
    healthyModuleCount: healthyCount,
    degradedModuleCount: degradedCount,
    criticalModuleCount: criticalCount,
  );
});