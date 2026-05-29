enum TraceStage {
  ingest,
  conflictResolved,
  stateReconciled,
  diffGenerated,
  patchCreated,
  queued,
  executed,
  rendered,
  error,
}

class DashboardTraceEvent {
  const DashboardTraceEvent({
    required this.id,
    required this.stage,
    required this.timestamp,
    required this.context,
  });

  final String id;
  final TraceStage stage;
  final DateTime timestamp;

  /// payload: event/module/widget/zone metadata
  final Map<String, dynamic> context;
}