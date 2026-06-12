/// ============================================================
/// RUNTIME TELEMETRY EVENT — IMMUTABLE DOMAIN MODEL
/// ============================================================
///
/// Phase 7A — Runtime Observability
///
/// PURPOSE:
/// Immutable value object representing a single observability
/// event within the dashboard engine runtime pipeline.
///
/// RULES:
/// - MUST be immutable (all final fields)
/// - MUST be timestamped (UTC)
/// - MUST carry a traceId for correlation
/// - MUST be serializable (for future persistence)
/// - MUST be lightweight (no heavy payloads)
///
/// These events flow through the RuntimeMetricsCollector.
/// They do NOT control execution — they only observe.
/// ============================================================

/// Categorizes the origin phase of a telemetry event.
enum TelemetryPhase {
  /// Pipeline: reconcile stage
  reconcile,

  /// Pipeline: diff stage
  diff,

  /// Pipeline: patch generation stage
  patch,

  /// Pipeline: patch execution stage
  execution,

  /// Replay/restore phase
  replay,

  /// Widget hydration phase
  hydration,

  /// Composition engine build phase
  composition,

  /// Frame scheduler / batching
  scheduler,

  /// Sync / reconnect
  sync,

  /// General runtime health
  runtime,

  /// Unknown / generic
  general,
}

/// Severity level for telemetry events
enum TelemetrySeverity {
  info,
  warning,
  error,
  critical,
}

/// Core telemetry event type — closed enum for exhaustive matching.
enum TelemetryEventType {
  /// Pipeline lifecycle
  pipelineStageStarted,
  pipelineStageCompleted,
  pipelineStageFailed,

  /// Replay lifecycle
  replayStarted,
  replayCompleted,
  replayFailureCaptured,
  replayBatchProcessed,

  /// Patch execution
  patchExecutionMeasured,
  patchExecutionFailed,
  patchRollbackTriggered,

  /// Rendering
  widgetRenderMeasured,
  widgetRebuildLoopDetected,

  /// Sync
  syncReconnectTriggered,
  syncReconnectSucceeded,
  syncReconnectFailed,

  /// Hydration
  hydrationStarted,
  hydrationCompleted,
  hydrationLatencyMeasured,

  /// Scheduler
  frameTaskDropped,
  frameBacklogWarning,
  frameBacklogCritical,

  /// Health
  healthDegraded,
  healthOverflow,
  healthRestored,

  /// Slow module detection (passive)
  slowModuleDetected,
  expensiveWidgetDetected,
  replayBottleneckDetected,
  excessiveRebuildLoopDetected,

  /// General
  metricsSampled,
  bufferCapacityWarning,
}

/// ============================================================
/// RUNTIME TELEMETRY EVENT
/// ============================================================
@immutable
class RuntimeTelemetryEvent {
  final String traceId;
  final String? moduleId;
  final String? widgetKey;
  final String? runtimeSessionId;
  final TelemetryEventType type;
  final TelemetryPhase phase;
  final TelemetrySeverity severity;
  final DateTime timestamp;
  final int durationMs;
  final Map<String, dynamic> metadata;

  const RuntimeTelemetryEvent({
    required this.traceId,
    this.moduleId,
    this.widgetKey,
    this.runtimeSessionId,
    required this.type,
    required this.phase,
    this.severity = TelemetrySeverity.info,
    required this.timestamp,
    this.durationMs = 0,
    this.metadata = const {},
  });

  // ─── Serialization ─────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'traceId': traceId,
        'moduleId': moduleId,
        'widgetKey': widgetKey,
        'runtimeSessionId': runtimeSessionId,
        'type': type.name,
        'phase': phase.name,
        'severity': severity.name,
        'timestamp': timestamp.toIso8601String(),
        'durationMs': durationMs,
        'metadata': metadata,
      };

  factory RuntimeTelemetryEvent.fromJson(Map<String, dynamic> json) =>
      RuntimeTelemetryEvent(
        traceId: json['traceId'] as String,
        moduleId: json['moduleId'] as String?,
        widgetKey: json['widgetKey'] as String?,
        runtimeSessionId: json['runtimeSessionId'] as String?,
        type: TelemetryEventType.values.byName(json['type'] as String),
        phase: TelemetryPhase.values.byName(json['phase'] as String),
        severity: TelemetrySeverity.values.byName(json['severity'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
        durationMs: json['durationMs'] as int? ?? 0,
        metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      );

  // ─── Copy (immutable update pattern) ──────────────────────
  RuntimeTelemetryEvent copyWith({
    String? traceId,
    String? moduleId,
    String? widgetKey,
    String? runtimeSessionId,
    TelemetryEventType? type,
    TelemetryPhase? phase,
    TelemetrySeverity? severity,
    DateTime? timestamp,
    int? durationMs,
    Map<String, dynamic>? metadata,
  }) =>
      RuntimeTelemetryEvent(
        traceId: traceId ?? this.traceId,
        moduleId: moduleId ?? this.moduleId,
        widgetKey: widgetKey ?? this.widgetKey,
        runtimeSessionId: runtimeSessionId ?? this.runtimeSessionId,
        type: type ?? this.type,
        phase: phase ?? this.phase,
        severity: severity ?? this.severity,
        timestamp: timestamp ?? this.timestamp,
        durationMs: durationMs ?? this.durationMs,
        metadata: metadata ?? this.metadata,
      );

  @override
  bool operator ==(Object other) =>
      other is RuntimeTelemetryEvent &&
      other.traceId == traceId &&
      other.type == type &&
      other.timestamp == timestamp;

  @override
  int get hashCode => Object.hash(traceId, type, timestamp);

  @override
  String toString() =>
      'RuntimeTelemetryEvent($type | ${phase.name} | ${timestamp})';
}

/// ============================================================
/// RUNTIME HEALTH SNAPSHOT
/// ============================================================
///
/// Aggregated runtime state model for observability & future
/// control plane integration.
///
/// This is a VALUE OBJECT — it does NOT perform any logic.
/// ============================================================
@immutable
class RuntimeHealthSnapshot {
  /// Replay health
  final int replayedEventCount;
  final int journalReplayDurationMs;
  final int checkpointRestoreDurationMs;

  /// Queue & buffer depth
  final int bufferEventCount;
  final int frameSchedulerBacklog;
  final int coalescerQueueSize;

  /// Failure tracking
  final int failureCount;
  final int droppedEventCount;
  final int reconnectAttemptCount;

  /// Pipeline performance
  final double averagePatchDurationMs;
  final double p50PatchDurationMs;
  final double p95PatchDurationMs;
  final double p99PatchDurationMs;
  final int totalPipelineRuns;

  /// Slow module detection
  final List<SlowModuleInfo> slowestModules;
  final int slowModuleCount;

  /// Reconnect frequency
  final int reconnectFrequency;

  /// Hydration latency
  final int hydrationLatencyMs;

  /// Throughput
  final double eventsPerSecond;
  final int totalEventsIngested;

  /// Health state
  final RuntimeHealthStatus healthStatus;
  final DateTime snapshotAt;

  const RuntimeHealthSnapshot({
    this.replayedEventCount = 0,
    this.journalReplayDurationMs = 0,
    this.checkpointRestoreDurationMs = 0,
    this.bufferEventCount = 0,
    this.frameSchedulerBacklog = 0,
    this.coalescerQueueSize = 0,
    this.failureCount = 0,
    this.droppedEventCount = 0,
    this.reconnectAttemptCount = 0,
    this.averagePatchDurationMs = 0,
    this.p50PatchDurationMs = 0,
    this.p95PatchDurationMs = 0,
    this.p99PatchDurationMs = 0,
    this.totalPipelineRuns = 0,
    this.slowestModules = const [],
    this.slowModuleCount = 0,
    this.reconnectFrequency = 0,
    this.hydrationLatencyMs = 0,
    this.eventsPerSecond = 0,
    this.totalEventsIngested = 0,
    this.healthStatus = RuntimeHealthStatus.healthy,
    required this.snapshotAt,
  });

  // ─── Serialization ─────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'replayedEventCount': replayedEventCount,
        'journalReplayDurationMs': journalReplayDurationMs,
        'checkpointRestoreDurationMs': checkpointRestoreDurationMs,
        'bufferEventCount': bufferEventCount,
        'frameSchedulerBacklog': frameSchedulerBacklog,
        'coalescerQueueSize': coalescerQueueSize,
        'failureCount': failureCount,
        'droppedEventCount': droppedEventCount,
        'reconnectAttemptCount': reconnectAttemptCount,
        'averagePatchDurationMs': averagePatchDurationMs,
        'p50PatchDurationMs': p50PatchDurationMs,
        'p95PatchDurationMs': p95PatchDurationMs,
        'p99PatchDurationMs': p99PatchDurationMs,
        'totalPipelineRuns': totalPipelineRuns,
        'slowModuleCount': slowModuleCount,
        'reconnectFrequency': reconnectFrequency,
        'hydrationLatencyMs': hydrationLatencyMs,
        'eventsPerSecond': eventsPerSecond,
        'totalEventsIngested': totalEventsIngested,
        'healthStatus': healthStatus.name,
        'snapshotAt': snapshotAt.toIso8601String(),
      };

  @override
  String toString() =>
      'RuntimeHealthSnapshot(health=$healthStatus, patches=${averagePatchDurationMs.toStringAsFixed(1)}ms, failures=$failureCount)';
}

/// ============================================================
/// SLOW MODULE INFO — PASSIVE WARNING ONLY
/// ============================================================
///
/// Used by RuntimeHealthSnapshot.slowestModules to identify
/// modules/widgets that exceed performance thresholds.
///
/// These are PASSIVE warnings only. Future governance phase
/// will use these to trigger interventions.
/// ============================================================
@immutable
class SlowModuleInfo {
  final String moduleId;
  final String? widgetKey;
  final String metricType; // 'patch', 'replay', 'rebuild', 'render'
  final int thresholdMs;
  final int actualMs;
  final DateTime detectedAt;
  final int occurrenceCount;

  const SlowModuleInfo({
    required this.moduleId,
    this.widgetKey,
    required this.metricType,
    required this.thresholdMs,
    required this.actualMs,
    required this.detectedAt,
    this.occurrenceCount = 1,
  });

  Map<String, dynamic> toJson() => {
        'moduleId': moduleId,
        'widgetKey': widgetKey,
        'metricType': metricType,
        'thresholdMs': thresholdMs,
        'actualMs': actualMs,
        'detectedAt': detectedAt.toIso8601String(),
        'occurrenceCount': occurrenceCount,
      };

  SlowModuleInfo copyWith({int? occurrenceCount}) =>
      SlowModuleInfo(
        moduleId: moduleId,
        widgetKey: widgetKey,
        metricType: metricType,
        thresholdMs: thresholdMs,
        actualMs: actualMs,
        detectedAt: detectedAt,
        occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      );

  @override
  String toString() =>
      'SlowModule($moduleId | $metricType: ${actualMs}ms > ${thresholdMs}ms)';
}

/// Runtime health status enum (mirrors RuntimeSyncEngine status)
enum RuntimeHealthStatus {
  healthy,
  recovering,
  degraded,
  replaying,
  overflow,
  corrupted;

  bool get isHealthy => this == healthy;
  bool get isCritical => this == overflow || this == corrupted;
}
