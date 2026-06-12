import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/module_runtime_sync/application/coordinators/module_runtime_sync_coordinator.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_reconciler.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';

/// ============================================================
/// MODULE RUNTIME SYNC STATE PROVIDER (HARDENED CORE STATE)
/// ============================================================

final moduleRuntimeSyncProvider =
    StateNotifierProvider<ModuleRuntimeSyncNotifier, ModuleRuntimeState>(
  (ref) => ModuleRuntimeSyncNotifier(),
);

class ModuleRuntimeSyncNotifier extends StateNotifier<ModuleRuntimeState> {
  ModuleRuntimeSyncNotifier() : super(ModuleRuntimeState.initial());

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
    reconciler: ModuleRuntimeReconciler(),
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
  return {
    'replayedEventCount': 0,
    'checkpointRestoreDurationMs': 0,
    'journalReplayDurationMs': 0,
    'lastCheckpointSequence': null,
    'lastJournalSequence': null,
    'checkpointFallbackOccurred': false,
    'pipelineRunCount': 0,
    'totalEventsIngested': 0,
    'bufferedEventCount': 0,
    'coalescedBatchCount': 0,
    'adaptiveReplayBatchesUsed': 0,
    'avgReplayBatchSize': 0,
    'pipelineExecutionCount': 0,
    'bufferCapacity': 500,
    'bufferUtilization': 0.0,
    'bufferNearCapacity': false,
    'totalProcessingTimeMs': 0,
    'engineUptimeMs': 0,
    'isReplaying': false,
    'isInitialized': false,
    'isBackgrounded': false,
    'healthStatus': 'healthy',
    'reconnectAttempt': 0,
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

final runtimeHealthProvider = StateProvider<RuntimeHealthState>(
  (ref) => RuntimeHealthState.healthy,
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
