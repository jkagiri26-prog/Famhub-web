enum TraceStage {
  ingest,
  patchCreated,
  patchExecutionStarted,
  patchExecutionCompleted,
  patchExecutionFailed,
}

class DashboardTraceEvent {
  final String id;
  final TraceStage stage;
  final DateTime timestamp;
  final Map<String, Object?> context;

  const DashboardTraceEvent({
    required this.id,
    required this.stage,
    required this.timestamp,
    this.context = const {},
  });

  /// 🧠 Safe factory for consistent event creation
  factory DashboardTraceEvent.now({
    required TraceStage stage,
    required String id,
    Map<String, Object?> context = const {},
  }) {
    return DashboardTraceEvent(
      id: id,
      stage: stage,
      timestamp: DateTime.now(),
      context: context,
    );
  }
}