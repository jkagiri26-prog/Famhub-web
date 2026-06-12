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

  /// Unique trace id (usually patch id or event id)
  final String id;

  /// Lifecycle stage inside dashboard_engine pipeline
  final TraceStage stage;

  final DateTime timestamp;

  /// ============================================================
  /// ENGINE CONTEXT PAYLOAD
  /// ============================================================
  /// MUST remain:
  /// - moduleKey
  /// - widgetKey
  /// - patchActionType
  /// - execution metadata
  ///
  /// MUST NOT contain:
  /// - zone controllers
  /// - UI state references
  /// - provider snapshots
  /// ============================================================
  final Map<String, dynamic> context;
}