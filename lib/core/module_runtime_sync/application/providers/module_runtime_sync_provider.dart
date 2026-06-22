

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/module_runtime_sync/application/coordinators/module_runtime_sync_coordinator.dart';
import 'package:famhub_app/core/module_runtime_sync/application/reconciliation/module_runtime_reconciler.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/observability_providers.dart';

/// ============================================================
/// MODULE RUNTIME SYNC STATE PROVIDER (HARDENED CORE STATE)
/// ============================================================

final moduleRuntimeSyncProvider =
    NotifierProvider<ModuleRuntimeSyncNotifier, ModuleRuntimeState>(
  ModuleRuntimeSyncNotifier.new,
);

class ModuleRuntimeSyncNotifier extends Notifier<ModuleRuntimeState> {
  @override
  ModuleRuntimeState build() => ModuleRuntimeState.initial();

  void updateState(ModuleRuntimeState nextState) {
    if (nextState == state) return;
    state = nextState;
  }

  void reset() {
    state = ModuleRuntimeState.initial();
  }
}

/// ============================================================
/// COORDINATOR PROVIDER
/// ============================================================

final moduleRuntimeSyncCoordinatorProvider =
    Provider<ModuleRuntimeSyncCoordinator>((ref) {
  return ModuleRuntimeSyncCoordinator(
    reconciler: const ModuleRuntimeReconciler(),
  );
});

/// ============================================================
/// PHASE 6 — TASK D1: RUNTIME DIAGNOSTICS PROVIDER
/// ============================================================
///
/// Provides comprehensive runtime diagnostics for developer tooling.
/// Wired to diagnostics panel (TASK D1).
///

final runtimeDiagnosticsProvider = Provider<Map<String, dynamic>>((ref) {
  // Wire real observability data into diagnostics
  final snapshot = ref.watch(latestHealthSnapshotProvider);
  final collector = ref.read(runtimeMetricsCollectorProvider);
  final resilience = ref.watch(resilienceMetricsProvider);

  if (snapshot == null) {
    return {
      'replayedEventCount': 0,
      'checkpointRestoreDurationMs': 0,
      'journalReplayDurationMs': 0,
      'lastCheckpointSequence': null,
      'lastJournalSequence': null,
      'checkpointFallbackOccurred': false,
      'pipelineRunCount': 0,
      'totalEventsIngested': collector.totalEvents,
      'bufferedEventCount': collector.bufferSize,
      'coalescedBatchCount': 0,
      'adaptiveReplayBatchesUsed': 0,
      'avgReplayBatchSize': 0,
      'pipelineExecutionCount': collector.totalEvents,
      'bufferCapacity': 500,
      'bufferUtilization': collector.bufferSize / 500.0,
      'bufferNearCapacity': collector.bufferSize > 400,
      'totalProcessingTimeMs': 0,
      'engineUptimeMs': collector.uptime.inMilliseconds,
      'isReplaying': false,
      'isInitialized': collector.totalEvents > 0,
      'isBackgrounded': false,
      'healthStatus': snapshot?.healthStatus.name ?? 'healthy',
      'reconnectAttempt': collector.recoveryCount,
      // Phase 3: additional real metrics
      'failureCount': collector.failureCount,
      'recoveryCount': collector.recoveryCount,
      'recoveryRate': resilience.recoveryRate,
      'consecutiveFailures': resilience.consecutiveFailures,
      'currentStreak': resilience.currentStreak,
      'mtbfMinutes': resilience.mtbfMinutes,
      'eventsPerSecond': collector.eventsPerSecond,
      'slowModuleCount': collector.slowModuleCount,
    };
  }

  return {
    'replayedEventCount': snapshot.totalEventsIngested,
    'checkpointRestoreDurationMs': snapshot.checkpointRestoreDurationMs,
    'journalReplayDurationMs': snapshot.journalReplayDurationMs,
    'lastCheckpointSequence': null,
    'lastJournalSequence': null,
    'checkpointFallbackOccurred': false,
    'pipelineRunCount': snapshot.totalPipelineRuns,
    'totalEventsIngested': snapshot.totalEventsIngested,
    'bufferedEventCount': snapshot.bufferEventCount,
    'coalescedBatchCount': 0,
    'adaptiveReplayBatchesUsed': 0,
    'avgReplayBatchSize': 0,
    'pipelineExecutionCount': snapshot.totalPipelineRuns,
    'bufferCapacity': 500,
    'bufferUtilization': snapshot.bufferEventCount / 500.0,
    'bufferNearCapacity': snapshot.bufferEventCount > 400,
    'totalProcessingTimeMs': 0,
    'engineUptimeMs': collector.uptime.inMilliseconds,
    'isReplaying': false,
    'isInitialized': snapshot.totalEventsIngested > 0,
    'isBackgrounded': false,
    'healthStatus': snapshot.healthStatus.name,
    'reconnectAttempt': snapshot.reconnectAttemptCount,
    // Phase 3: additional real metrics
    'failureCount': snapshot.failureCount,
    'recoveryCount': collector.recoveryCount,
    'recoveryRate': resilience.recoveryRate,
    'consecutiveFailures': resilience.consecutiveFailures,
    'currentStreak': resilience.currentStreak,
    'mtbfMinutes': resilience.mtbfMinutes,
    'eventsPerSecond': snapshot.eventsPerSecond,
    'slowModuleCount': snapshot.slowModuleCount,
    'averagePatchDurationMs': snapshot.averagePatchDurationMs,
    'p95PatchDurationMs': snapshot.p95PatchDurationMs,
  };
});

/// ============================================================
/// PHASE 6 — TASK D3: RUNTIME HEALTH PROVIDER
/// ============================================================
///
/// Exposes operational health for dashboards and logging.
///

enum RuntimeHealthState {
  healthy,
  recovering,
  degraded,
  replaying,
  overflow,
  corrupted;

  bool get isCritical => this == overflow || this == corrupted;
  bool get isOperational => this == healthy;
}

class RuntimeHealthNotifier extends Notifier<RuntimeHealthState> {
  @override
  RuntimeHealthState build() => RuntimeHealthState.healthy;

  void setState(RuntimeHealthState newState) => state = newState;
  void setHealthy() => state = RuntimeHealthState.healthy;
  void setDegraded() => state = RuntimeHealthState.degraded;
  void setOverflow() => state = RuntimeHealthState.overflow;
  void setCorrupted() => state = RuntimeHealthState.corrupted;
}

final runtimeHealthProvider =
    NotifierProvider<RuntimeHealthNotifier, RuntimeHealthState>(
  RuntimeHealthNotifier.new,
);

/// ============================================================
/// PHASE 6 — TASK G2: FEATURE FLAGS PROVIDER
/// ============================================================
///
/// Enables safe production tuning of runtime controls.
///

class RuntimeFeatureFlags {
  final bool enableCheckpointing;
  final bool enableCompaction;
  final bool enableReplayMetrics;
  final bool enableDiagnosticsPanel;
  final bool enableAdaptiveBatching;

  const RuntimeFeatureFlags({
    this.enableCheckpointing = true,
    this.enableCompaction = true,
    this.enableReplayMetrics = true,
    this.enableDiagnosticsPanel = false,
    this.enableAdaptiveBatching = true,
  });
}

final runtimeFeatureFlagsProvider = Provider<RuntimeFeatureFlags>(
  (ref) => const RuntimeFeatureFlags(),
);

/// ============================================================
/// LEGACY: RECOVERY METRICS PROVIDER (BACKWARD COMPATIBLE)
/// ============================================================

final recoveryMetricsProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.read(runtimeDiagnosticsProvider);
});
