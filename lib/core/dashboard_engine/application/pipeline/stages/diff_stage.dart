import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_context.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_stage.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_diff.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_reconciler.dart';

class DiffStage implements RuntimePipelineStage<ModuleRuntimeState,
    DashboardRuntimePatch, DashboardRuntimeDiff> {
  DiffStage({
    required this.reconciler,
  });

  final DashboardRuntimeReconciler reconciler;

  @override
  Future<void> execute(
    RuntimePipelineContext<ModuleRuntimeState, DashboardRuntimePatch,
            DashboardRuntimeDiff>
        context,
  ) async {
    final nextState = context.nextState;

    if (nextState == null) return;

    final diff = reconciler.generateDiff(
      previous: context.currentState,
      next: nextState,
    );

    context.setDiff(diff);
  }
}