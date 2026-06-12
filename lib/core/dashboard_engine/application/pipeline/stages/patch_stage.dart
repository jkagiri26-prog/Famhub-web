import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_context.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_stage.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_diff.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_reconciler.dart';

class PatchStage implements RuntimePipelineStage<ModuleRuntimeState,
    DashboardRuntimePatch, DashboardRuntimeDiff> {
  PatchStage({
    required this.reconciler,
  });

  final DashboardRuntimeReconciler reconciler;

  @override
  Future<void> execute(
    RuntimePipelineContext<ModuleRuntimeState, DashboardRuntimePatch,
            DashboardRuntimeDiff>
        context,
  ) async {
    final diff = context.diff;

    /// ------------------------------------------------------------
    /// SAFETY: no diff → no patch
    /// ------------------------------------------------------------
    if (diff == null) return;

    /// ------------------------------------------------------------
    /// SAFETY: ensure diff actually contains changes
    /// (prevents no-op patch generation)
    /// ------------------------------------------------------------
    if (!diff.hasChanges) return;

        /// ------------------------------------------------------------
    /// DEPENDENCY RESOLUTION (MUST HAPPEN FIRST)
    /// ------------------------------------------------------------
    final resolvedDiff = reconciler.resolveDependencies(diff);

    /// ------------------------------------------------------------
    /// PATCH GENERATION (FROM RESOLVED DIFF)
    /// ------------------------------------------------------------
    final patch = reconciler.generatePatch(resolvedDiff);

    /// ------------------------------------------------------------
    /// SAFETY: invalid or empty patch guard
    /// ------------------------------------------------------------
    if (patch.isEmpty) return;

    /// ------------------------------------------------------------
    /// SAFE ASSIGNMENT (PIPELINE CONTRACT)
    /// ------------------------------------------------------------
    context.setPatch(patch);
  }
}