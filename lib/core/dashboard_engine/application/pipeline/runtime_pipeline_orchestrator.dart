import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_context.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_stage.dart';

typedef StageFailureHandler<TState, TPatch, TDiff>
    = void Function(
        RuntimePipelineStage<TState, TPatch, TDiff> stage,
        Object error,
        StackTrace stack,
      );

class RuntimePipelineOrchestrator<TState, TPatch, TDiff> {
  RuntimePipelineOrchestrator({
    required this.stages,
    this.onStageFailure,
    this.failFast = false,
  });

  final List<RuntimePipelineStage<TState, TPatch, TDiff>> stages;

  /// Optional observability hook
  final StageFailureHandler<TState, TPatch, TDiff>? onStageFailure;

  /// If true → pipeline stops immediately on error
  final bool failFast;

  Future<void> run(
    RuntimePipelineContext<TState, TPatch, TDiff> context,
  ) async {
    try {
      for (final stage in stages) {
        final sw = Stopwatch()..start();

        try {
          await stage.execute(context);

          sw.stop();

          context.metadata[
                  'stage_${stage.runtimeType}_ms'] =
              sw.elapsedMilliseconds;

        } catch (e, stack) {
          sw.stop();

          context.metadata['stage_failure'] = {
            'stage': stage.runtimeType.toString(),
            'error': e.toString(),
            'durationMs': sw.elapsedMilliseconds,
          };

          onStageFailure?.call(
            stage,
            e,
            stack,
          );

          if (failFast) {
            rethrow;
          }

          continue;
        }
      }
    } finally {
      /// ==========================================================
      /// HARD LIFECYCLE BOUNDARY
      /// ==========================================================
      context.finalize();
    }
  }
}