class DashboardRuntimeHealthSnapshot {
  final int coalescerQueueSize;
  final int frameSchedulerBacklog;
  final Duration? lastPatchExecutionDuration;
  final DateTime? lastRollbackAt;
  final int? activeZoneCount;

  const DashboardRuntimeHealthSnapshot({
    required this.coalescerQueueSize,
    required this.frameSchedulerBacklog,
    this.lastPatchExecutionDuration,
    this.lastRollbackAt,
    this.activeZoneCount,
  });

  factory DashboardRuntimeHealthSnapshot.fromMetrics({
    required int coalescerQueueSize,
    required int frameSchedulerBacklog,
    Duration? lastPatchExecutionDuration,
    DateTime? lastRollbackAt,
    int? activeZoneCount,
  }) {
    return DashboardRuntimeHealthSnapshot(
      coalescerQueueSize: coalescerQueueSize,
      frameSchedulerBacklog: frameSchedulerBacklog,
      lastPatchExecutionDuration: lastPatchExecutionDuration,
      lastRollbackAt: lastRollbackAt,
      activeZoneCount: activeZoneCount,
    );
  }
}
