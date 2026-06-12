import 'dart:async';

import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/observability/runtime_metrics_collector.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_context.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_stage.dart';

/// ============================================================
/// PIPELINE INSTRUMENTATION ADAPTER — PHASE 7A
/// ============================================================
///
/// PURPOSE:
/// Wraps EXISTING pipeline stages with passive instrumentation.
/// Measures duration, collects telemetry, and records metrics
/// WITHOUT modifying stage behavior.
///
/// RULES:
/// - Does NOT rewrite stages
/// - Does NOT alter execution flow
/// - Does NOT mutate context
/// - Does NOT inject rendering behavior
/// - Does NOT change reconciliation logic
///
/// IMPLEMENTATION:
///   final stopwatch = Stopwatch()..start();
///   await stage.execute(context);
///   stopwatch.stop();
///   telemetry.record(...);
///
/// This is the ONLY place where pipeline measurement happens.
/// ============================================================

/// Identifies pipeline stages for telemetry purposes
enum PipelineStageId {
  reconcile,
  diff,
  patch,
  execution,
  replay,
  hydration,
  composition,
}

/// ============================================================
/// INSTRUMENTED PIPELINE STAGE WRAPPER
/// ============================================================
///
/// Wraps a single RuntimePipelineStage with passive measurement.
///
/// Usage:
/// ```dart
/// final instrumented = InstrumentedStage(
///   stageId: PipelineStageId.reconcile,
///   inner: ReconciliationStage(coordinator: coordinator),
///   collector: metricsCollector,
///   traceId: traceId,
/// );
/// ```
///
/// The instrumented stage delegates everything to the inner stage.
/// It only adds timing + telemetry around the execute() call.
/// ============================================================
class InstrumentedStage<TState, TPatch, TDiff>
    implements RuntimePipelineStage<TState, TPatch, TDiff> {
  InstrumentedStage({
    required this.stageId,
    required this.inner,
    required this.collector,
    required this.traceId,
    this.runtimeSessionId,
  });

  final PipelineStageId stageId;
  final RuntimePipelineStage<TState, TPatch, TDiff> inner;
  final RuntimeMetricsCollector collector;
  final String traceId;
  final String? runtimeSessionId;

  @override
  String get name => 'Instrumented(${inner.name})';

  @override
  Future<void> execute(
    RuntimePipelineContext<TState, TPatch, TDiff> context,
  ) async {
    final sw = Stopwatch()..start();

    // ── Record start ──
    collector.record(RuntimeTelemetryEvent(
      traceId: traceId,
      runtimeSessionId: runtimeSessionId,
      type: TelemetryEventType.pipelineStageStarted,
      phase: _phaseForStage(stageId),
      timestamp: DateTime.now(),
      metadata: {
        'stage': stageId.name,
        'innerStage': inner.name,
      },
    ));

    try {
      // ── Delegate to inner stage (NO BEHAVIOR MODIFICATION) ──
      await inner.execute(context);

      sw.stop();

      // ── Record completion ──
      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        runtimeSessionId: runtimeSessionId,
        type: TelemetryEventType.pipelineStageCompleted,
        phase: _phaseForStage(stageId),
        timestamp: DateTime.now(),
        durationMs: sw.elapsedMilliseconds,
        metadata: {
          'stage': stageId.name,
          'innerStage': inner.name,
          'hasOutput': _hasStageOutput(context, stageId),
        },
      ));
    } catch (e, stack) {
      sw.stop();

      // ── Record failure (passive — does NOT rethrow or suppress) ──
      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        runtimeSessionId: runtimeSessionId,
        type: TelemetryEventType.pipelineStageFailed,
        phase: _phaseForStage(stageId),
        severity: TelemetrySeverity.error,
        timestamp: DateTime.now(),
        durationMs: sw.elapsedMilliseconds,
        metadata: {
          'stage': stageId.name,
          'error': e.toString(),
        },
      ));

      // MUST rethrow — we observe only, we don't swallow errors
      rethrow;
    }
  }

  /// Determine if the stage produced output in the context
  bool _hasStageOutput(
    RuntimePipelineContext<TState, TPatch, TDiff> context,
    PipelineStageId sid,
  ) {
    switch (sid) {
      case PipelineStageId.reconcile:
        return context.hasNextState;
      case PipelineStageId.diff:
        return context.hasDiff;
      case PipelineStageId.patch:
        return context.hasPatch;
      case PipelineStageId.execution:
        return context.wasMutated;
      default:
        return false;
    }
  }

  TelemetryPhase _phaseForStage(PipelineStageId id) {
    switch (id) {
      case PipelineStageId.reconcile:
        return TelemetryPhase.reconcile;
      case PipelineStageId.diff:
        return TelemetryPhase.diff;
      case PipelineStageId.patch:
        return TelemetryPhase.patch;
      case PipelineStageId.execution:
        return TelemetryPhase.execution;
      case PipelineStageId.replay:
        return TelemetryPhase.replay;
      case PipelineStageId.hydration:
        return TelemetryPhase.hydration;
      case PipelineStageId.composition:
        return TelemetryPhase.composition;
    }
  }

  // ─── Delegated lifecycle hooks ───────────────────────────

  @override
  Future<void> beforeExecute(
    RuntimePipelineContext<TState, TPatch, TDiff> context,
  ) async {
    await inner.beforeExecute(context);
  }

  @override
  Future<void> afterExecute(
    RuntimePipelineContext<TState, TPatch, TDiff> context,
  ) async {
    await inner.afterExecute(context);
  }
}

/// ============================================================
/// INSTRUMENTED ORCHESTRATOR WRAPPER
/// ============================================================
///
/// Wraps the entire pipeline orchestrator run with measurements.
///
/// This measures total pipeline duration but does NOT replace
/// the orchestrator. The orchestrator still owns stage execution.
/// ============================================================
class InstrumentedOrchestrator<TState, TPatch, TDiff> {
  InstrumentedOrchestrator({
    required this.collector,
    required this.traceId,
    this.runtimeSessionId,
  });

  final RuntimeMetricsCollector collector;
  final String traceId;
  final String? runtimeSessionId;

  /// Wrap an orchestrator run with telemetry
  Future<void> runInstrumented(
    Future<void> Function() orchestratorRun,
  ) async {
    final sw = Stopwatch()..start();

    try {
      await orchestratorRun();
      sw.stop();

      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        runtimeSessionId: runtimeSessionId,
        type: TelemetryEventType.pipelineStageCompleted,
        phase: TelemetryPhase.general,
        timestamp: DateTime.now(),
        durationMs: sw.elapsedMilliseconds,
        metadata: {
          'pipeline': 'full',
          'status': 'success',
        },
      ));
    } catch (e) {
      sw.stop();
      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        runtimeSessionId: runtimeSessionId,
        type: TelemetryEventType.pipelineStageFailed,
        phase: TelemetryPhase.general,
        severity: TelemetrySeverity.error,
        timestamp: DateTime.now(),
        durationMs: sw.elapsedMilliseconds,
        metadata: {
          'pipeline': 'full',
          'error': e.toString(),
        },
      ));
      rethrow;
    }
  }
}

/// ============================================================
/// PATCH EXECUTION INSTRUMENTATION
/// ============================================================
///
/// Standalone utility to measure a single patch execution.
///
/// Usage in SafeDashboardPatchExecutor:
/// ```dart
/// PatchInstrumentation.measure(
///   collector: metricsCollector,
///   patchId: patch.id,
///   moduleId: patch.moduleKey,
///   traceId: traceId,
///   action: () => executeSafely(patch),
/// );
/// ```
/// ============================================================
class PatchInstrumentation {
  /// Measure a patch execution and record telemetry
  static Future<T> measure<T>({
    required RuntimeMetricsCollector collector,
    required String patchId,
    required String? moduleId,
    required String traceId,
    String? runtimeSessionId,
    required Future<T> Function() action,
  }) async {
    final sw = Stopwatch()..start();

    try {
      final result = await action();
      sw.stop();

      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        moduleId: moduleId,
        runtimeSessionId: runtimeSessionId,
        type: TelemetryEventType.patchExecutionMeasured,
        phase: TelemetryPhase.execution,
        timestamp: DateTime.now(),
        durationMs: sw.elapsedMilliseconds,
        metadata: {
          'patchId': patchId,
          'status': 'success',
          'durationMs': sw.elapsedMilliseconds,
        },
      ));

      return result;
    } catch (e) {
      sw.stop();

      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        moduleId: moduleId,
        runtimeSessionId: runtimeSessionId,
        type: TelemetryEventType.patchExecutionFailed,
        phase: TelemetryPhase.execution,
        severity: TelemetrySeverity.error,
        timestamp: DateTime.now(),
        durationMs: sw.elapsedMilliseconds,
        metadata: {
          'patchId': patchId,
          'error': e.toString(),
        },
      ));

      rethrow;
    }
  }
}

/// ============================================================
/// REPLAY INSTRUMENTATION
/// ============================================================
///
/// Utility to instrument replay operations.
///
/// Usage in RuntimeSyncEngine._replayDelta():
/// ```dart
/// ReplayInstrumentation.measure(
///   collector: metricsCollector,
///   traceId: traceId,
///   eventCount: events.length,
///   action: () => _replayDelta(),
/// );
/// ```
/// ============================================================
class ReplayInstrumentation {
  static Future<T> measure<T>({
    required RuntimeMetricsCollector collector,
    required String traceId,
    required int eventCount,
    String? runtimeSessionId,
    required Future<T> Function() action,
  }) async {
    collector.record(RuntimeTelemetryEvent(
      traceId: traceId,
      runtimeSessionId: runtimeSessionId,
      type: TelemetryEventType.replayStarted,
      phase: TelemetryPhase.replay,
      timestamp: DateTime.now(),
      metadata: {'eventCount': eventCount},
    ));

    final sw = Stopwatch()..start();

    try {
      final result = await action();
      sw.stop();

      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        runtimeSessionId: runtimeSessionId,
        type: TelemetryEventType.replayCompleted,
        phase: TelemetryPhase.replay,
        timestamp: DateTime.now(),
        durationMs: sw.elapsedMilliseconds,
        metadata: {
          'eventCount': eventCount,
          'durationMs': sw.elapsedMilliseconds,
        },
      ));

      return result;
    } catch (e) {
      sw.stop();

      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        runtimeSessionId: runtimeSessionId,
        type: TelemetryEventType.replayFailureCaptured,
        phase: TelemetryPhase.replay,
        severity: TelemetrySeverity.error,
        timestamp: DateTime.now(),
        durationMs: sw.elapsedMilliseconds,
        metadata: {
          'eventCount': eventCount,
          'error': e.toString(),
        },
      ));

      rethrow;
    }
  }
}

/// ============================================================
/// HYDRATION INSTRUMENTATION
/// ============================================================
class HydrationInstrumentation {
  static Future<T> measure<T>({
    required RuntimeMetricsCollector collector,
    required String traceId,
    String? runtimeSessionId,
    required Future<T> Function() action,
  }) async {
    collector.record(RuntimeTelemetryEvent(
      traceId: traceId,
      runtimeSessionId: runtimeSessionId,
      type: TelemetryEventType.hydrationStarted,
      phase: TelemetryPhase.hydration,
      timestamp: DateTime.now(),
    ));

    final sw = Stopwatch()..start();

    try {
      final result = await action();
      sw.stop();

      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        runtimeSessionId: runtimeSessionId,
        type: TelemetryEventType.hydrationCompleted,
        phase: TelemetryPhase.hydration,
        timestamp: DateTime.now(),
        durationMs: sw.elapsedMilliseconds,
        metadata: {'durationMs': sw.elapsedMilliseconds},
      ));

      return result;
    } catch (e) {
      sw.stop();
      rethrow;
    }
  }
}

/// ============================================================
/// FRAME SCHEDULER INSTRUMENTATION
/// ============================================================
///
/// Provides callbacks for DashboardFrameScheduler observability hooks.
/// ============================================================
class FrameSchedulerInstrumentation {
  FrameSchedulerInstrumentation({
    required this.collector,
    required this.traceId,
    this.runtimeSessionId,
  });

  final RuntimeMetricsCollector collector;
  final String traceId;
  final String? runtimeSessionId;

  /// Callback for frame backlog warnings
  void Function(int backlog) get onBacklogWarning => (int backlog) {
        collector.record(RuntimeTelemetryEvent(
          traceId: traceId,
          runtimeSessionId: runtimeSessionId,
          type: TelemetryEventType.frameBacklogWarning,
          phase: TelemetryPhase.scheduler,
          severity: TelemetrySeverity.warning,
          timestamp: DateTime.now(),
          metadata: {'backlog': backlog},
        ));

        if (backlog >= 30) {
          collector.record(RuntimeTelemetryEvent(
            traceId: traceId,
            runtimeSessionId: runtimeSessionId,
            type: TelemetryEventType.frameBacklogCritical,
            phase: TelemetryPhase.scheduler,
            severity: TelemetrySeverity.critical,
            timestamp: DateTime.now(),
            metadata: {'backlog': backlog},
          ));
        }
      };

  /// Callback for dropped tasks
  void Function() get onDroppedTask => () {
        collector.record(RuntimeTelemetryEvent(
          traceId: traceId,
          runtimeSessionId: runtimeSessionId,
          type: TelemetryEventType.frameTaskDropped,
          phase: TelemetryPhase.scheduler,
          severity: TelemetrySeverity.warning,
          timestamp: DateTime.now(),
        ));
      };
}
