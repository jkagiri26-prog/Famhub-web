import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_context.dart';

/// ============================================================
/// PIPELINE STAGE CONTRACT (HARDENED)
/// ============================================================
///
/// RULES:
/// - Every stage has identity (for tracing)
/// - Execution is wrapped by orchestrator, not stage
/// - Optional hooks for lifecycle observability
/// - Stateless by default (no internal mutation assumptions)
/// ============================================================

abstract class RuntimePipelineStage<TState, TPatch, TDiff> {
  /// Unique identifier for tracing/debugging
  String get name => runtimeType.toString();

  /// Optional: called before execution
  Future<void> beforeExecute(RuntimePipelineContext<TState, TPatch, TDiff> context) async {}

  /// Core stage logic (must be implemented)
  Future<void> execute(RuntimePipelineContext<TState, TPatch, TDiff> context);

  /// Optional: called after execution
  Future<void> afterExecute(RuntimePipelineContext<TState, TPatch, TDiff> context) async {}

  /// ============================================================
  /// INTERNAL EXECUTION WRAPPER (DO NOT OVERRIDE IN STAGES)
  /// ============================================================
  Future<void> run(RuntimePipelineContext<TState, TPatch, TDiff> context) async {
    await beforeExecute(context);
    await execute(context);
    await afterExecute(context);
  }
}