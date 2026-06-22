/// ============================================================
/// STRUCTURED OBSERVABILITY LOGGING BRIDGE — PHASE 7A
/// ============================================================
///
/// PURPOSE:
/// Provides structured logging integration for telemetry events.
/// Integrates with the existing logging infrastructure without
/// creating another logging framework.
///
/// Every telemetry event supports:
/// - traceId
/// - moduleId
/// - runtimeSessionId
/// - timestamp
/// - severity
/// - execution phase
///
/// RULES:
/// - Do NOT create another logging framework
/// - Do NOT log every frame blindly
/// - Do NOT spam telemetry
/// - Do NOT serialize giant payloads
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';

/// Severity mapping for observability log output
enum LogSeverity {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Structured log entry for observability
class ObservabilityLogEntry {
  final String traceId;
  final String? moduleId;
  final String? widgetKey;
  final String? runtimeSessionId;
  final String message;
  final TelemetryEventType eventType;
  final TelemetryPhase phase;
  final TelemetrySeverity severity;
  final DateTime timestamp;
  final int? durationMs;
  final Map<String, dynamic> context;

  const ObservabilityLogEntry({
    required this.traceId,
    this.moduleId,
    this.widgetKey,
    this.runtimeSessionId,
    required this.message,
    required this.eventType,
    required this.phase,
    this.severity = TelemetrySeverity.info,
    required this.timestamp,
    this.durationMs,
    this.context = const {},
  });

  Map<String, dynamic> toJson() => {
        'traceId': traceId,
        'moduleId': moduleId,
        'widgetKey': widgetKey,
        'runtimeSessionId': runtimeSessionId,
        'message': message,
        'eventType': eventType.name,
        'phase': phase.name,
        'severity': severity.name,
        'timestamp': timestamp.toIso8601String(),
        'durationMs': durationMs,
        'context': context,
      };

  @override
  String toString() =>
      '[${severity.name.toUpperCase()}] [$phase] [$traceId] $message'
      '${durationMs != null ? ' (${durationMs}ms)' : ''}'
      '${moduleId != null ? ' [$moduleId]' : ''}';
}

/// ============================================================
/// OBSERVABILITY LOGGER
/// ============================================================
///
/// Lightweight structured logging for observability.
///
/// Integrates with existing print-based logging (RuntimeSyncEngine._log)
/// and provides structured output that can be consumed by:
/// - Developer diagnostics panel
/// - Future telemetry export pipeline
/// - Future analytics integration
///
/// USAGE:
/// ```dart
/// final logger = ObservabilityLogger(
///   runtimeSessionId: sessionId,
/// );
/// logger.info(traceId, 'Replay completed', event, durationMs: 150);
/// logger.warning(traceId, 'Buffer near capacity', event);
/// logger.error(traceId, 'Replay failed', event, error: e);
/// ```
/// ============================================================
class ObservabilityLogger {
  ObservabilityLogger({
    this.runtimeSessionId,
    this.enableConsoleLogging = true,
  });

  final String? runtimeSessionId;
  final bool enableConsoleLogging;

  // ─── LOGGING METHODS ──────────────────────────────────────

  void info(
    String traceId, {
    String? moduleId,
    String? widgetKey,
    TelemetryEventType? eventType,
    TelemetryPhase? phase,
    String? message,
    int? durationMs,
    Map<String, dynamic>? context,
  }) {
    _log(
      traceId: traceId,
      moduleId: moduleId,
      widgetKey: widgetKey,
      message: message ?? eventType?.name ?? 'Observability event',
      eventType: eventType ?? TelemetryEventType.metricsSampled,
      phase: phase ?? TelemetryPhase.general,
      severity: TelemetrySeverity.info,
      durationMs: durationMs,
      context: context,
    );
  }

  void warning(
    String traceId, {
    String? moduleId,
    String? widgetKey,
    TelemetryEventType? eventType,
    TelemetryPhase? phase,
    required String message,
    int? durationMs,
    Map<String, dynamic>? context,
  }) {
    _log(
      traceId: traceId,
      moduleId: moduleId,
      widgetKey: widgetKey,
      message: message,
      eventType: eventType ?? TelemetryEventType.metricsSampled,
      phase: phase ?? TelemetryPhase.general,
      severity: TelemetrySeverity.warning,
      durationMs: durationMs,
      context: context,
    );
  }

  void error(
    String traceId, {
    String? moduleId,
    String? widgetKey,
    TelemetryEventType? eventType,
    TelemetryPhase? phase,
    required String message,
    int? durationMs,
    Object? error,
    Map<String, dynamic>? context,
  }) {
    _log(
      traceId: traceId,
      moduleId: moduleId,
      widgetKey: widgetKey,
      message: message,
      eventType: eventType ?? TelemetryEventType.metricsSampled,
      phase: phase ?? TelemetryPhase.general,
      severity: TelemetrySeverity.error,
      durationMs: durationMs,
      context: {
        ...?context,
        if (error != null) 'error': error.toString(),
      },
    );
  }

  void critical(
    String traceId, {
    String? moduleId,
    String? widgetKey,
    TelemetryEventType? eventType,
    TelemetryPhase? phase,
    required String message,
    int? durationMs,
    Object? error,
    Map<String, dynamic>? context,
  }) {
    _log(
      traceId: traceId,
      moduleId: moduleId,
      widgetKey: widgetKey,
      message: message,
      eventType: eventType ?? TelemetryEventType.metricsSampled,
      phase: phase ?? TelemetryPhase.general,
      severity: TelemetrySeverity.critical,
      durationMs: durationMs,
      context: {
        ...?context,
        if (error != null) 'error': error.toString(),
      },
    );
  }

  // ─── INTERNAL ────────────────────────────────────────────

  void _log({
    required String traceId,
    String? moduleId,
    String? widgetKey,
    required String message,
    required TelemetryEventType eventType,
    required TelemetryPhase phase,
    required TelemetrySeverity severity,
    int? durationMs,
    Map<String, dynamic>? context,
  }) {
    final entry = ObservabilityLogEntry(
      traceId: traceId,
      moduleId: moduleId,
      widgetKey: widgetKey,
      runtimeSessionId: runtimeSessionId,
      message: message,
      eventType: eventType,
      phase: phase,
      severity: severity,
      timestamp: DateTime.now(),
      durationMs: durationMs,
      context: context ?? const {},
    );

    if (enableConsoleLogging) {
      // ignore: avoid_print
      print('[Observability] ${entry.toString()}');
    }

    // Future: integrate with structured logging service
    // Future: emit to telemetry export pipeline
  }

  /// Convert a telemetry event to a structured log entry
  ObservabilityLogEntry fromTelemetryEvent(
    RuntimeTelemetryEvent event, {
    String? message,
  }) {
    return ObservabilityLogEntry(
      traceId: event.traceId,
      moduleId: event.moduleId,
      widgetKey: event.widgetKey,
      runtimeSessionId: event.runtimeSessionId,
      message: message ?? 'Telemetry: ${event.type.name}',
      eventType: event.type,
      phase: event.phase,
      severity: event.severity,
      timestamp: event.timestamp,
      durationMs: event.durationMs > 0 ? event.durationMs : null,
      context: event.metadata,
    );
  }
}
