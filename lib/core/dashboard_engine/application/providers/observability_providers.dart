import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/observability/runtime_metrics_collector.dart';
import 'package:famhub_app/core/dashboard_engine/application/observability/observability_logger.dart';

/// ============================================================
/// OBSERVABILITY PROVIDERS — PHASE 7A
/// ============================================================
///
/// PURPOSE:
/// Riverpod dependency injection for the observability layer.
///
/// RULES:
/// - Single instance per app lifecycle
/// - No UI logic here — providers only
/// - Read-only streams exposed where possible
/// ============================================================

// ─── RUNTIME SESSION ID ─────────────────────────────────────

/// Singleton runtime session identifier for this app lifecycle.
final runtimeSessionIdProvider = Provider<String>((ref) {
  return 'rs-${DateTime.now().millisecondsSinceEpoch}-${_randomSuffix()}';
});

String _randomSuffix() {
  return (DateTime.now().microsecondsSinceEpoch % 10000).toString();
}

// ─── RUNTIME METRICS COLLECTOR ─────────────────────────────

final runtimeMetricsCollectorProvider =
    Provider<RuntimeMetricsCollector>((ref) {
  final collector = RuntimeMetricsCollector();
  collector.start();

  ref.onDispose(() {
    collector.dispose();
  });

  return collector;
});

// ─── OBSERVABILITY LOGGER ─────────────────────────────────

final observabilityLoggerProvider = Provider<ObservabilityLogger>((ref) {
  final sessionId = ref.read(runtimeSessionIdProvider);
  return ObservabilityLogger(
    runtimeSessionId: sessionId,
    enableConsoleLogging: true,
  );
});

// ─── HEALTH SNAPSHOT STREAM PROVIDER ──────────────────────

/// Reactive read-only stream of runtime health snapshots.
///
/// This is the PRIMARY diagnostics stream for:
/// - Developer diagnostics panel
/// - Future admin console
/// - Future telemetry export
///
/// The stream is throttled internally by the collector
/// to avoid excessive emissions.
final runtimeHealthSnapshotStreamProvider =
    StreamProvider<RuntimeHealthSnapshot>((ref) {
  final collector = ref.read(runtimeMetricsCollectorProvider);
  return collector.healthSnapshotStream;
});

// ─── LATEST HEALTH SNAPSHOT ────────────────────────────────

/// Pull-based access to the latest health snapshot.
/// Auto-updates when the stream emits a new value.
final latestHealthSnapshotProvider = Provider<RuntimeHealthSnapshot?>((ref) {
  final streamValue = ref.watch(runtimeHealthSnapshotStreamProvider);
  return streamValue.valueOrNull;
});

// ─── RAW TELEMETRY EVENT STREAM ────────────────────────────

/// Raw telemetry event stream for advanced consumers.
/// WARNING: High-frequency stream — throttle consumption.
final rawTelemetryEventStreamProvider =
    StreamProvider<RuntimeTelemetryEvent>((ref) {
  final collector = ref.read(runtimeMetricsCollectorProvider);
  return collector.rawEventStream;
});

// ─── FEATURE FLAG: OBSERVABILITY ENABLED ──────────────────

/// Feature flag to enable/disable observability layer.
/// When disabled, collectors no-op and UI is hidden.
final observabilityEnabledProvider = StateProvider<bool>((ref) {
  // Default: enabled in debug, disabled in release
  // Can be overridden by feature flags or config
  return true;
});

// ─── DIAGNOSTICS PANEL VISIBILITY ─────────────────────────

/// Controls visibility of the developer diagnostics overlay.
/// Dev-only — not for production.
final diagnosticsPanelVisibleProvider = StateProvider<bool>((ref) {
  return false;
});

// ─── SLOW MODULE LIST PROVIDER ────────────────────────────

/// Exposes the current list of detected slow modules.
/// Derived from the latest health snapshot.
final slowModuleListProvider = Provider<List<SlowModuleInfo>>((ref) {
  final snapshot = ref.watch(latestHealthSnapshotProvider);
  return snapshot?.slowestModules ?? const [];
});

// ─── OBSERVABILITY METRICS SUMMARY ────────────────────────

/// Human-readable summary of current observability metrics.
final observabilitySummaryProvider = Provider<ObservabilitySummary>((ref) {
  final snapshot = ref.watch(latestHealthSnapshotProvider);
  final collector = ref.read(runtimeMetricsCollectorProvider);

  return ObservabilitySummary(
    healthStatus: snapshot?.healthStatus ?? RuntimeHealthStatus.healthy,
    totalEvents: collector.totalEvents,
    eventsPerSecond: collector.eventsPerSecond,
    failures: collector.failureCount,
    droppedEvents: collector.droppedEventCount,
    slowModuleCount: collector.slowModuleCount,
    bufferSize: collector.bufferSize,
    averagePatchDurationMs: snapshot?.averagePatchDurationMs ?? 0,
    p95PatchDurationMs: snapshot?.p95PatchDurationMs ?? 0,
  );
});

/// Simple value object for summary display
class ObservabilitySummary {
  final RuntimeHealthStatus healthStatus;
  final int totalEvents;
  final double eventsPerSecond;
  final int failures;
  final int droppedEvents;
  final int slowModuleCount;
  final int bufferSize;
  final double averagePatchDurationMs;
  final double p95PatchDurationMs;

  const ObservabilitySummary({
    required this.healthStatus,
    required this.totalEvents,
    required this.eventsPerSecond,
    required this.failures,
    required this.droppedEvents,
    required this.slowModuleCount,
    required this.bufferSize,
    required this.averagePatchDurationMs,
    required this.p95PatchDurationMs,
  });
}
