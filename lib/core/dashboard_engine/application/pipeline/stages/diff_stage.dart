import '../../../../../core/module_runtime_sync/domain/models/module_runtime_state.dart';
import '../runtime_pipeline_context.dart';
import '../runtime_pipeline_stage.dart';
import '../../reconciliation/dashboard_runtime_diff.dart';
import '../../reconciliation/dashboard_runtime_patch.dart';
import '../../reconciliation/dashboard_runtime_reconciler.dart';

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