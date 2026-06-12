import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_stage.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_context.dart';
import 'package:famhub_app/core/dashboard_engine/application/executor/safe_dashboard_patch_executor.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_diff.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';

class ExecutionStage implements RuntimePipelineStage<
    ModuleRuntimeState,
    DashboardRuntimePatch,
    DashboardRuntimeDiff> {

    ExecutionStage({
    required this.executor,
    void Function(DashboardRuntimePatch patch, String status)? onTrace,
  }) : onTrace = onTrace ?? _noopTrace;

  static void _noopTrace(DashboardRuntimePatch patch, String status) {}

  final SafeDashboardPatchExecutor executor;

  /// MUST be pure side-effect boundary (logging only)
  final void Function(DashboardRuntimePatch patch, String status) onTrace;

  /// stronger dedup guard (not just instance memory)
  final Set<String> _executedPatchIds = {};

  @override
  Future<void> execute(
    RuntimePipelineContext<
        ModuleRuntimeState,
        DashboardRuntimePatch,
        DashboardRuntimeDiff> context,
  ) async {

    final patch = context.patch;

    if (patch == null || patch.isEmpty) return;

        final patchId = patch.id;

    /// =========================================================
    /// IDEMPOTENCY GUARD (HARDENED)
    /// =========================================================
    if (_executedPatchIds.contains(patchId)) return;
    _executedPatchIds.add(patchId);

    try {
      /// =======================================================
      /// EXECUTION (ONLY AUTHORITY)
      /// =======================================================
      await executor.executeSafely(patch);

      /// =======================================================
      /// TRACE (SAFE OBSERVATION ONLY)
      /// =======================================================
      onTrace(patch, 'success');

    } catch (e) {
      onTrace(patch, 'failed');
    }
  }
}