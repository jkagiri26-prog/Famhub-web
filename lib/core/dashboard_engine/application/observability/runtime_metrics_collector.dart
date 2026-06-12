import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';

/// ============================================================
/// ANALYTICS TIME WINDOW (PHASE 3)
/// ============================================================
class AnalyticsWindow {
  final DateTime windowStart;
  final DateTime windowEnd;
  final int eventCount;
  final int failureCount;
  final int recoveryCount;
  final double avgPatchDurationMs;
  final double p95PatchDurationMs;
  final double throughputEps;

  const AnalyticsWindow({
    required this.windowStart,
    required this.windowEnd,
    required this.eventCount,
    required this.failureCount,
    required this.recoveryCount,
    required this.avgPatchDurationMs,
    required this.p95PatchDurationMs,
    required this.throughputEps,
  });

  Map<String, dynamic> toJson() => {
        'windowStart': windowStart.toIso8601String(),
        'windowEnd': windowEnd.toIso8601String(),
        'eventCount': eventCount,
        'failureCount': failureCount,
        'recoveryCount': recoveryCount,
        'avgPatchDurationMs': avgPatchDurationMs,
        'p95PatchDurationMs': p95PatchDurationMs,
        'throughputEps': throughputEps,
      };
}

/// ============================================================
/// MODULE METRICS SNAPSHOT (PHASE 3)
/// ============================================================
class ModuleMetrics {
  final String moduleId;
  int patchCount;
  int failureCount;
  int recoveryCount;
  int totalDurationMs;
  int maxDurationMs;
  double avgDurationMs;
  double degradationScore;
  DateTime lastActivityAt;

  ModuleMetrics({
    required this.moduleId,
    this.patchCount = 0,
    this.failureCount = 0,
    this.recoveryCount = 0,
    this.totalDurationMs = 0,
    this.maxDurationMs = 0,
    this.avgDurationMs = 0,
    this.degradationScore = 0,
    DateTime? lastActivityAt,
  }) : lastActivityAt = lastActivityAt ?? DateTime.now();

  void recordPatch(int durationMs) {
    patchCount++;
    totalDurationMs += durationMs;
    maxDurationMs = max(maxDurationMs, durationMs);
    avgDurationMs = totalDurationMs / patchCount;
    lastActivityAt = DateTime.now();
  }

  void recordFailure() {
    failureCount++;
    degradationScore = min(1.0, degradationScore + 0.1);
    lastActivityAt = DateTime.now();
  }

  void recordRecovery() {
    recoveryCount++;
    degradationScore = max(0.0, degradationScore - 0.15);
    lastActivityAt = DateTime.now();
  }

  double get healthIndex {
    if (patchCount == 0) return 1.0;
    final failureRatio = failureCount / patchCount;
    final durPenalty = avgDurationMs > 200 ? 0.2 : 0.0;
    return (1.0 - failureRatio - durPenalty - degradationScore).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'moduleId': moduleId,
        'patchCount': patchCount,
        'failureCount': failureCount,
        'recoveryCount': recoveryCount,
        'avgDurationMs': avgDurationMs,
        'maxDurationMs': maxDurationMs,
        'degradationScore': degradationScore,
        'healthIndex': healthIndex,
        'lastActivityAt': lastActivityAt.toIso8601String(),
      };
}

/// ============================================================
/// RESILIENCE METRICS (PHASE 3)
/// ============================================================
class ResilienceMetrics {
  final DateTime? uptimeSince;
  final int totalRecoveries;
  final int totalFailures;
  final double recoveryRate;
  final double mtbfMinutes;
  final double mttrSeconds;
  final int currentStreak;
  final int maxStreak;
  final int consecutiveFailures;

  const ResilienceMetrics({
    required this.uptimeSince,
    required this.totalRecoveries,
    required this.totalFailures,
    required this.recoveryRate,
    required this.mtbfMinutes,
    required this.mttrSeconds,
    required this.currentStreak,
    required this.maxStreak,
    required this.consecutiveFailures,
  });

  bool get isHealthy => recoveryRate > 0.8 && consecutiveFailures < 3;
  bool get isWarning => recoveryRate > 0.5 && consecutiveFailures < 10;

  static const empty = ResilienceMetrics(
    uptimeSince: null,
    totalRecoveries: 0,
    totalFailures: 0,
    recoveryRate: 1.0,
    mtbfMinutes: double.infinity,
    mttrSeconds: 0,
    currentStreak: 0,
    maxStreak: 0,
    consecutiveFailures: 0,
  );

  Map<String, dynamic> toJson() => {
        'uptimeSince': uptimeSince?.toIso8601String() ?? 'N/A',
        'totalRecoveries': totalRecoveries,
        'totalFailures': totalFailures,
        'recoveryRate': recoveryRate,
        'mtbfMinutes': mtbfMinutes,
        'mttrSeconds': mttrSeconds,
        'currentStreak': currentStreak,
        'maxStreak': maxStreak,
        'consecutiveFailures': consecutiveFailures,
      };
}

/// ============================================================
/// RUNTIME METRICS COLLECTOR — PHASE 7A + PHASE 3 EXPANSION
/// ============================================================
///
/// PURPOSE:
/// Central aggregation service for runtime measurements within
/// the dashboard engine. Collects, aggregates, and exposes
/// telemetry data from the instrumentation layer.
///
/// PHASE 3 EXTENSIONS:
/// - Time-series analytics aggregation (rolling windows)
/// - Resilience KPIs (uptime tracking, recovery rate, MTBF)
/// - Module-level performance histograms
/// - Degradation trend scoring
///
/// RESPONSIBILITIES:
/// - Aggregate metrics from telemetry events
/// - Maintain rolling statistics (averages, percentiles)
/// - Track throughput (events/sec, patch latency)
/// - Detect slow modules (threshold-driven, passive)
/// - Expose streams for diagnostics consumers
///
/// NON-RESPONSIBILITIES:
/// - Persisting data directly (optional, future phase)
/// - Rendering UI (presentation layer responsibility)
/// - Controlling runtime (observes only)
/// - Mutating runtime state
///
/// ARCHITECTURAL RULES:
/// - Non-blocking collection only
/// - No synchronous disk writes
/// - No large object allocations in hot paths
/// - Batching for high-throughput scenarios
/// - Thread-safe (single-threaded Dart, but re-entrant safe)
/// ============================================================
class RuntimeMetricsCollector {
  RuntimeMetricsCollector({
    this.maxMetricsBufferSize = 1000,
    this.slowPatchThresholdMs = 100,
    this.slowReplayThresholdMs = 500,
    this.slowRenderThresholdMs = 50,
    this.slowRebuildThresholdMs = 30,
    this.percentileBufferSize = 500,
    this.throttleStreamInterval = const Duration(milliseconds: 100),
    this.analyticsWindowDuration = const Duration(minutes: 5),
    this.maxAnalyticsWindows = 12,
  });

  // ─── CONFIGURABLE THRESHOLDS ──────────────────────────────
  final int maxMetricsBufferSize;
  final int slowPatchThresholdMs;
  final int slowReplayThresholdMs;
  final int slowRenderThresholdMs;
  final int slowRebuildThresholdMs;
  final int percentileBufferSize;
  final Duration throttleStreamInterval;
  final Duration analyticsWindowDuration;
  final int maxAnalyticsWindows;

  // ─── INTERNAL STATE ───────────────────────────────────────
  final Queue<RuntimeTelemetryEvent> _metricsBuffer = Queue();
  final List<double> _patchDurationSamples = [];
  final List<double> _replayDurationSamples = [];
  final List<double> _renderDurationSamples = [];
  final List<double> _hydrationDurationSamples = [];

  final Map<String, List<int>> _moduleDurationTrack = {};
  final Map<String, int> _moduleSlowOccurrences = {};

  final List<SlowModuleInfo> _slowModules = [];

  int _failureCount = 0;
  int _recoveryCount = 0;
  int _droppedEventCount = 0;
  int _reconnectAttemptCount = 0;
  int _reconnectSuccessCount = 0;
  int _totalPipelineRuns = 0;
  int _totalEventsIngested = 0;
  int _frameBacklogWarnings = 0;
  int _frameBacklogCritical = 0;
  int _bufferCapacityWarnings = 0;
  int _currentStreak = 0;
  int _maxStreak = 0;
  int _consecutiveFailures = 0;
  int _totalRecoveries = 0;
  DateTime? _lastFailureAt;
  DateTime? _lastRecoveryAt;
  DateTime? _uptimeSince;

  DateTime _startTime = DateTime.now();
  int _eventsInCurrentSecond = 0;
  double _currentEps = 0;

  // ─── PHASE 3: Analytics aggregation ──────────────────────
  final List<AnalyticsWindow> _analyticsHistory = [];
  DateTime _currentWindowStart = DateTime.now();
  int _windowEventCount = 0;
  int _windowFailureCount = 0;
  int _windowRecoveryCount = 0;
  final List<double> _windowPatchDurations = [];

  // ─── PHASE 3: Module metrics ────────────────────────────
  final Map<String, ModuleMetrics> _moduleMetrics = {};

  final StreamController<RuntimeHealthSnapshot> _snapshotController =
      StreamController<RuntimeHealthSnapshot>.broadcast();
  Timer? _throttleTimer;
  RuntimeHealthSnapshot? _latestSnapshot;
  int _throttledEmitCount = 0;

  final StreamController<RuntimeTelemetryEvent> _rawEventController =
      StreamController<RuntimeTelemetryEvent>.broadcast();

  // ─── PUBLIC STREAMS ───────────────────────────────────────

  /// Reactive health snapshot stream (throttled, read-only)
  Stream<RuntimeHealthSnapshot> get healthSnapshotStream =>
      _snapshotController.stream;

  /// Raw telemetry event stream (for advanced consumers)
  Stream<RuntimeTelemetryEvent> get rawEventStream =>
      _rawEventController.stream;

  /// Latest computed snapshot (non-null after first emission)
  RuntimeHealthSnapshot? get latestSnapshot => _latestSnapshot;

  // ─── PHASE 3: New public accessors ────────────────────────

  /// Get module-specific metrics
  ModuleMetrics? moduleMetrics(String moduleId) => _moduleMetrics[moduleId];

  /// All module metrics snapshot
  Map<String, ModuleMetrics> get allModuleMetrics =>
      Map.unmodifiable(_moduleMetrics);

  /// Analytics history (time-series windows)
  List<AnalyticsWindow> get analyticsHistory =>
      List.unmodifiable(_analyticsHistory);

  /// Compute resilience metrics
  ResilienceMetrics get resilienceMetrics {
    final uptime = _uptimeSince;
    if (uptime == null) return ResilienceMetrics.empty;

    final uptimeMinutes = DateTime.now().difference(uptime).inMinutes;
    final recoveryRate = _totalFailures > 0
        ? _totalRecoveries / (_totalFailures + _totalRecoveries)
        : 1.0;
    final mtbf = _totalFailures > 0
        ? uptimeMinutes / _totalFailures
        : double.infinity;
    final mttr = _totalRecoveries > 0 && _lastFailureAt != null && _lastRecoveryAt != null
        ? _lastRecoveryAt!.difference(_lastFailureAt!).inSeconds / _totalRecoveries
        : 0.0;

    return ResilienceMetrics(
      uptimeSince: uptime,
      totalRecoveries: _totalRecoveries,
      totalFailures: _totalFailures,
      recoveryRate: recoveryRate,
      mtbfMinutes: mtbf,
      mttrSeconds: mttr,
      currentStreak: _currentStreak,
      maxStreak: _maxStreak,
      consecutiveFailures: _consecutiveFailures,
    );
  }

  /// Get the health index for a specific module
  double moduleHealthIndex(String moduleId) {
    return _moduleMetrics[moduleId]?.healthIndex ?? 1.0;
  }

  /// Current uptime duration
  Duration get uptime => _uptimeSince != null
      ? DateTime.now().difference(_uptimeSince!)
      : Duration.zero;

  // ─── LIFECYCLE ────────────────────────────────────────────

  void start() {
    _startTime = DateTime.now();
    _uptimeSince = DateTime.now();
    _currentWindowStart = DateTime.now();
  }

  void dispose() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _snapshotController.close();
    _rawEventController.close();
    _metricsBuffer.clear();
    _patchDurationSamples.clear();
    _replayDurationSamples.clear();
    _renderDurationSamples.clear();
    _hydrationDurationSamples.clear();
    _moduleDurationTrack.clear();
    _moduleSlowOccurrences.clear();
    _slowModules.clear();
  }

  // ─── EVENT INGESTION ──────────────────────────────────────

  /// Record a telemetry event (non-blocking, O(1) amortized)
  void record(RuntimeTelemetryEvent event) {
    _totalEventsIngested++;
    _eventsInCurrentSecond++;
    _windowEventCount++;

    // ── Module metrics tracking ──
    if (event.moduleId != null) {
      _moduleMetrics.putIfAbsent(
        event.moduleId!,
        () => ModuleMetrics(moduleId: event.moduleId!),
      );
    }

    // ── Buffer management ──
    _metricsBuffer.add(event);
    if (_metricsBuffer.length > maxMetricsBufferSize) {
      _metricsBuffer.removeFirst();
      _droppedEventCount++;
    }

    // ── Raw emission (for advanced consumers) ──
    if (!_rawEventController.isClosed) {
      _rawEventController.add(event);
    }

    // ── Phase-specific aggregation ──
    switch (event.type) {
      case TelemetryEventType.pipelineStageStarted:
      case TelemetryEventType.pipelineStageCompleted:
        _totalPipelineRuns++;
        break;

      case TelemetryEventType.patchExecutionMeasured:
        _recordPatchDuration(event.durationMs, event.moduleId);
        _moduleMetrics[event.moduleId]?.recordPatch(event.durationMs);
        break;

      case TelemetryEventType.patchExecutionFailed:
        _failureCount++;
        _windowFailureCount++;
        _consecutiveFailures++;
        _currentStreak = 0;
        _lastFailureAt = DateTime.now();
        _moduleMetrics[event.moduleId]?.recordFailure();
        break;

      case TelemetryEventType.patchRollbackTriggered:
        _failureCount++;
        _windowFailureCount++;
        _consecutiveFailures++;
        _currentStreak = 0;
        _lastFailureAt = DateTime.now();
        break;

      case TelemetryEventType.replayStarted:
      case TelemetryEventType.replayCompleted:
        if (event.durationMs > 0) {
          _replayDurationSamples.add(event.durationMs.toDouble());
          _trimList(_replayDurationSamples, percentileBufferSize);
        }
        break;

      case TelemetryEventType.replayFailureCaptured:
        _failureCount++;
        _windowFailureCount++;
        break;

      case TelemetryEventType.replayBottleneckDetected:
        if (event.moduleId != null) {
          _trackSlowModule(
            moduleId: event.moduleId!,
            widgetKey: event.widgetKey,
            metricType: 'replay',
            thresholdMs: slowReplayThresholdMs,
            actualMs: event.durationMs,
          );
        }
        break;

      case TelemetryEventType.widgetRenderMeasured:
        if (event.durationMs > 0) {
          _renderDurationSamples.add(event.durationMs.toDouble());
          _trimList(_renderDurationSamples, percentileBufferSize);
        }
        if (event.durationMs >= slowRenderThresholdMs && event.moduleId != null) {
          _trackSlowModule(
            moduleId: event.moduleId!,
            widgetKey: event.widgetKey,
            metricType: 'render',
            thresholdMs: slowRenderThresholdMs,
            actualMs: event.durationMs,
          );
        }
        break;

      case TelemetryEventType.widgetRebuildLoopDetected:
        if (event.moduleId != null) {
          _trackSlowModule(
            moduleId: event.moduleId!,
            widgetKey: event.widgetKey,
            metricType: 'rebuild',
            thresholdMs: slowRebuildThresholdMs,
            actualMs: event.durationMs,
          );
        }
        break;

      case TelemetryEventType.syncReconnectTriggered:
        _reconnectAttemptCount++;
        break;

      case TelemetryEventType.syncReconnectSucceeded:
        _reconnectSuccessCount++;
        _recoveryCount++;
        _windowRecoveryCount++;
        _totalRecoveries++;
        _consecutiveFailures = 0;
        _currentStreak++;
        _maxStreak = max(_maxStreak, _currentStreak);
        _lastRecoveryAt = DateTime.now();
        _moduleMetrics[event.moduleId]?.recordRecovery();
        break;

      case TelemetryEventType.syncReconnectFailed:
        _reconnectAttemptCount++;
        _failureCount++;
        _windowFailureCount++;
        break;

      case TelemetryEventType.hydrationLatencyMeasured:
        if (event.durationMs > 0) {
          _hydrationDurationSamples.add(event.durationMs.toDouble());
          _trimList(_hydrationDurationSamples, percentileBufferSize);
        }
        break;

      case TelemetryEventType.frameTaskDropped:
        _droppedEventCount++;
        break;

      case TelemetryEventType.frameBacklogWarning:
        _frameBacklogWarnings++;
        break;

      case TelemetryEventType.frameBacklogCritical:
        _frameBacklogCritical++;
        break;

      case TelemetryEventType.bufferCapacityWarning:
        _bufferCapacityWarnings++;
        break;

      case TelemetryEventType.slowModuleDetected:
      case TelemetryEventType.expensiveWidgetDetected:
        if (event.moduleId != null) {
          _trackSlowModule(
            moduleId: event.moduleId!,
            widgetKey: event.widgetKey,
            metricType: event.type == TelemetryEventType.slowModuleDetected
                ? 'patch'
                : 'render',
            thresholdMs: slowPatchThresholdMs,
            actualMs: event.durationMs,
          );
        }
        break;

      case TelemetryEventType.excessiveRebuildLoopDetected:
        if (event.moduleId != null) {
          _trackSlowModule(
            moduleId: event.moduleId!,
            widgetKey: event.widgetKey,
            metricType: 'rebuild',
            thresholdMs: slowRebuildThresholdMs,
            actualMs: event.durationMs,
          );
        }
        break;

      case TelemetryEventType.healthRestored:
        _recoveryCount++;
        _windowRecoveryCount++;
        _totalRecoveries++;
        _consecutiveFailures = 0;
        _currentStreak++;
        _maxStreak = max(_maxStreak, _currentStreak);
        break;

      case TelemetryEventType.metricsSampled:
      case TelemetryEventType.healthDegraded:
      case TelemetryEventType.healthOverflow:
      case TelemetryEventType.hydrationStarted:
      case TelemetryEventType.hydrationCompleted:
      case TelemetryEventType.replayBatchProcessed:
      case TelemetryEventType.pipelineStageFailed:
        // Tracked via other counters
        break;
    }

    // ── Phase 3: Roll analytics window ──
    _checkAnalyticsWindow();

    // ── Throttled health snapshot emission ──
    _scheduleThrottledSnapshot();
  }

  // ─── PHASE 3: Analytics window management ─────────────────

  void _checkAnalyticsWindow() {
    final now = DateTime.now();
    if (now.difference(_currentWindowStart) >= analyticsWindowDuration) {
      _finalizeAnalyticsWindow();
      _currentWindowStart = now;
      _windowEventCount = 0;
      _windowFailureCount = 0;
      _windowRecoveryCount = 0;
      _windowPatchDurations.clear();
    }
  }

  void _finalizeAnalyticsWindow() {
    final sorted = List<double>.from(_windowPatchDurations)..sort();
    final avg = _windowPatchDurations.isEmpty
        ? 0.0
        : _windowPatchDurations.reduce((a, b) => a + b) / _windowPatchDurations.length;
    final p95 = _percentile(sorted, 95);

    final window = AnalyticsWindow(
      windowStart: _currentWindowStart,
      windowEnd: DateTime.now(),
      eventCount: _windowEventCount,
      failureCount: _windowFailureCount,
      recoveryCount: _windowRecoveryCount,
      avgPatchDurationMs: avg,
      p95PatchDurationMs: p95,
      throughputEps: analyticsWindowDuration.inSeconds > 0
          ? _windowEventCount / analyticsWindowDuration.inSeconds
          : 0,
    );

    _analyticsHistory.add(window);
    if (_analyticsHistory.length > maxAnalyticsWindows) {
      _analyticsHistory.removeAt(0);
    }
  }

  // ─── STATISTICS ───────────────────────────────────────────

  /// Compute rolling average from a list of doubles
  double _average(List<double> samples) {
    if (samples.isEmpty) return 0;
    return samples.reduce((a, b) => a + b) / samples.length;
  }

  /// Compute percentile (0–100) from sorted samples
  double _percentile(List<double> sortedSamples, double p) {
    if (sortedSamples.isEmpty) return 0;
    if (sortedSamples.length == 1) return sortedSamples.first;

    final rank = (p / 100) * (sortedSamples.length - 1);
    final lower = rank.floor();
    final upper = rank.ceil();

    if (lower == upper) return sortedSamples[lower];

    final frac = rank - lower;
    return sortedSamples[lower] * (1 - frac) + sortedSamples[upper] * frac;
  }

  /// Get sorted copy of patch duration samples
  List<double> get _sortedPatchSamples =>
      List<double>.from(_patchDurationSamples)..sort();

  List<double> get _sortedReplaySamples =>
      List<double>.from(_replayDurationSamples)..sort();

  List<double> get _sortedRenderSamples =>
      List<double>.from(_renderDurationSamples)..sort();

  // ─── PATCH DURATION TRACKING ────────────────────────────

  void _recordPatchDuration(int durationMs, String? moduleId) {
    if (durationMs <= 0) return;

    _patchDurationSamples.add(durationMs.toDouble());
    _trimList(_patchDurationSamples, percentileBufferSize);

    // Track per-module for slow module detection
    if (moduleId != null) {
      _moduleDurationTrack.putIfAbsent(moduleId, () => []);
      _moduleDurationTrack[moduleId]!.add(durationMs);
      _trimList(_moduleDurationTrack[moduleId]!, 50);

      if (durationMs >= slowPatchThresholdMs) {
        _trackSlowModule(
          moduleId: moduleId,
          widgetKey: null,
          metricType: 'patch',
          thresholdMs: slowPatchThresholdMs,
          actualMs: durationMs,
        );
      }
    }
  }

  // ─── SLOW MODULE DETECTION ─────────────────────────────

  void _trackSlowModule({
    required String moduleId,
    String? widgetKey,
    required String metricType,
    required int thresholdMs,
    required int actualMs,
  }) {
    final existingIndex = _slowModules.indexWhere(
      (m) =>
          m.moduleId == moduleId &&
          m.widgetKey == widgetKey &&
          m.metricType == metricType,
    );

    if (existingIndex >= 0) {
      final existing = _slowModules[existingIndex];
      _slowModules[existingIndex] = existing.copyWith(
        occurrenceCount: existing.occurrenceCount + 1,
      );
    } else {
      _slowModules.add(SlowModuleInfo(
        moduleId: moduleId,
        widgetKey: widgetKey,
        metricType: metricType,
        thresholdMs: thresholdMs,
        actualMs: actualMs,
        detectedAt: DateTime.now(),
      ));
    }

    // Keep only top N slow modules by occurrence count
    _slowModules.sort((a, b) => b.occurrenceCount.compareTo(a.occurrenceCount));
    if (_slowModules.length > 20) {
      _slowModules.removeRange(20, _slowModules.length);
    }
  }

  // ─── THROTTLED SNAPSHOT EMISSION ────────────────────────

  void _scheduleThrottledSnapshot() {
    if (_throttleTimer != null) return;

    _throttleTimer = Timer(throttleStreamInterval, () {
      _throttleTimer = null;
      _emitSnapshot();
    });
  }

  void _emitSnapshot() {
    if (_snapshotController.isClosed) return;

    // Compute EPS
    final elapsed = DateTime.now().difference(_startTime);
    _currentEps = elapsed.inSeconds > 0
        ? _totalEventsIngested / elapsed.inSeconds
        : 0;

    final sortedPatch = _sortedPatchSamples;

    final snapshot = RuntimeHealthSnapshot(
      replayedEventCount: _totalEventsIngested,
      journalReplayDurationMs: _replayDurationSamples.isNotEmpty
          ? _replayDurationSamples.last.round()
          : 0,
      checkpointRestoreDurationMs: 0,
      bufferEventCount: _metricsBuffer.length,
      frameSchedulerBacklog: 0,
      coalescerQueueSize: 0,
      failureCount: _failureCount,
      droppedEventCount: _droppedEventCount,
      reconnectAttemptCount: _reconnectAttemptCount,
      averagePatchDurationMs: _average(_patchDurationSamples),
      p50PatchDurationMs: _percentile(sortedPatch, 50),
      p95PatchDurationMs: _percentile(sortedPatch, 95),
      p99PatchDurationMs: _percentile(sortedPatch, 99),
      totalPipelineRuns: _totalPipelineRuns,
      slowestModules: List.unmodifiable(_slowModules),
      slowModuleCount: _slowModules.length,
      reconnectFrequency: _reconnectAttemptCount,
      hydrationLatencyMs: _average(_hydrationDurationSamples).round(),
      eventsPerSecond: _currentEps,
      totalEventsIngested: _totalEventsIngested,
      healthStatus: _deriveHealthStatus(),
      snapshotAt: DateTime.now(),
    );

    _latestSnapshot = snapshot;

    if (!_snapshotController.isClosed) {
      _snapshotController.add(snapshot);
      _throttledEmitCount++;
    }

    // Reset per-second counter
    _eventsInCurrentSecond = 0;
  }

  RuntimeHealthStatus _deriveHealthStatus() {
    if (_failureCount > 50 || _frameBacklogCritical > 10 || _consecutiveFailures > 20) {
      return RuntimeHealthStatus.critical;
    }
    if (_bufferCapacityWarnings > 5 || _frameBacklogWarnings > 20 || _consecutiveFailures > 5) {
      return RuntimeHealthStatus.degraded;
    }
    return RuntimeHealthStatus.healthy;
  }

  // ─── HELPERS ───────────────────────────────────────────────

  void _trimList(List list, int maxSize) {
    while (list.length > maxSize) {
      list.removeAt(0);
    }
  }

  // ─── DEBUG / DIAGNOSTIC ACCESSORS ───────────────────────

  /// Number of events currently buffered
  int get bufferSize => _metricsBuffer.length;

  /// Total events ingested since start
  int get totalEvents => _totalEventsIngested;

  /// Current events-per-second estimate
  double get eventsPerSecond => _currentEps;

  /// Number of throttled snapshot emissions
  int get throttledEmitCount => _throttledEmitCount;

  /// Number of recorded failures
  int get failureCount => _failureCount;

  /// Number of recorded recoveries
  int get recoveryCount => _recoveryCount;

  /// Number of dropped events (buffer overflow)
  int get droppedEventCount => _droppedEventCount;

  /// Number of slow modules currently tracked
  int get slowModuleCount => _slowModules.length;

  /// Dump current slow module list
  List<SlowModuleInfo> get slowModules => List.unmodifiable(_slowModules);

  /// Clear all metrics (for testing / reset)
  void reset() {
    _metricsBuffer.clear();
    _patchDurationSamples.clear();
    _replayDurationSamples.clear();
    _renderDurationSamples.clear();
    _hydrationDurationSamples.clear();
    _moduleDurationTrack.clear();
    _moduleSlowOccurrences.clear();
    _slowModules.clear();
    _failureCount = 0;
    _recoveryCount = 0;
    _droppedEventCount = 0;
    _reconnectAttemptCount = 0;
    _reconnectSuccessCount = 0;
    _totalPipelineRuns = 0;
    _totalEventsIngested = 0;
    _frameBacklogWarnings = 0;
    _frameBacklogCritical = 0;
    _bufferCapacityWarnings = 0;
    _currentStreak = 0;
    _maxStreak = 0;
    _consecutiveFailures = 0;
    _totalRecoveries = 0;
    _lastFailureAt = null;
    _lastRecoveryAt = null;
    _uptimeSince = DateTime.now();
    _startTime = DateTime.now();
    _eventsInCurrentSecond = 0;
    _currentEps = 0;
    _latestSnapshot = null;
    _analyticsHistory.clear();
    _moduleMetrics.clear();
    _currentWindowStart = DateTime.now();
    _windowEventCount = 0;
    _windowFailureCount = 0;
    _windowRecoveryCount = 0;
    _windowPatchDurations.clear();
  }
}
