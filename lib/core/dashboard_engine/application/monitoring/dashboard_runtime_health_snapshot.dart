/// ============================================================
/// DASHBOARD RUNTIME HEALTH SNAPSHOT — PHASE 3 EXPANSION
/// ============================================================
///
/// PHASE 3 EXTENSIONS:
/// - Resilience KPIs: recovery rate, MTBF, MTTF, streak tracking
/// - Module health indices
/// - Analytics window data
///
/// EXTENDS the existing snapshot — does NOT replace it.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class DashboardRuntimeHealthSnapshot {
  final int coalescerQueueSize;
  final int frameSchedulerBacklog;
  final Duration? lastPatchExecutionDuration;
  final DateTime? lastRollbackAt;
  final int? activeZoneCount;

  // ─── PHASE 3: Resilience KPIs ─────────────────────────────
  final int totalFailures;
  final int totalRecoveries;
  final double recoveryRate;
  final int currentStreak;
  final int maxStreak;
  final int consecutiveFailures;
  final double mtbfMinutes;
  final double mttrSeconds;

  // ─── PHASE 3: Module health ──────────────────────────────
  final int moduleCount;
  final int healthyModuleCount;
  final int degradedModuleCount;
  final int criticalModuleCount;

  const DashboardRuntimeHealthSnapshot({
    required this.coalescerQueueSize,
    required this.frameSchedulerBacklog,
    this.lastPatchExecutionDuration,
    this.lastRollbackAt,
    this.activeZoneCount,
    this.totalFailures = 0,
    this.totalRecoveries = 0,
    this.recoveryRate = 1.0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.consecutiveFailures = 0,
    this.mtbfMinutes = double.infinity,
    this.mttrSeconds = 0,
    this.moduleCount = 0,
    this.healthyModuleCount = 0,
    this.degradedModuleCount = 0,
    this.criticalModuleCount = 0,
  });

  factory DashboardRuntimeHealthSnapshot.fromMetrics({
    required int coalescerQueueSize,
    required int frameSchedulerBacklog,
    Duration? lastPatchExecutionDuration,
    DateTime? lastRollbackAt,
    int? activeZoneCount,
    int totalFailures = 0,
    int totalRecoveries = 0,
    double recoveryRate = 1.0,
    int currentStreak = 0,
    int maxStreak = 0,
    int consecutiveFailures = 0,
    double mtbfMinutes = double.infinity,
    double mttrSeconds = 0,
    int moduleCount = 0,
    int healthyModuleCount = 0,
    int degradedModuleCount = 0,
    int criticalModuleCount = 0,
  }) {
    return DashboardRuntimeHealthSnapshot(
      coalescerQueueSize: coalescerQueueSize,
      frameSchedulerBacklog: frameSchedulerBacklog,
      lastPatchExecutionDuration: lastPatchExecutionDuration,
      lastRollbackAt: lastRollbackAt,
      activeZoneCount: activeZoneCount,
      totalFailures: totalFailures,
      totalRecoveries: totalRecoveries,
      recoveryRate: recoveryRate,
      currentStreak: currentStreak,
      maxStreak: maxStreak,
      consecutiveFailures: consecutiveFailures,
      mtbfMinutes: mtbfMinutes,
      mttrSeconds: mttrSeconds,
      moduleCount: moduleCount,
      healthyModuleCount: healthyModuleCount,
      degradedModuleCount: degradedModuleCount,
      criticalModuleCount: criticalModuleCount,
    );
  }
}

