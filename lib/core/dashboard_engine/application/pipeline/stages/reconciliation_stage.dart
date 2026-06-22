import 'package:famhub_app/core/module_runtime_sync/domain/events/module_runtime_event.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';
import 'package:famhub_app/core/module_runtime_sync/application/coordinators/module_runtime_sync_coordinator.dart';

import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_context.dart';
import 'package:famhub_app/core/dashboard_engine/application/pipeline/runtime_pipeline_stage.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_diff.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';

class ReconciliationStage
    implements RuntimePipelineStage<ModuleRuntimeState,
        DashboardRuntimePatch, DashboardRuntimeDiff> {
  ReconciliationStage({
    required this.coordinator,
  });

  final ModuleRuntimeSyncCoordinator coordinator;

  @override
  String get name => 'ReconciliationStage';

  @override
  Future<void> beforeExecute(
    RuntimePipelineContext<ModuleRuntimeState, DashboardRuntimePatch,
            DashboardRuntimeDiff>
        context,
  ) async {
    // No-op
  }

  @override
  Future<void> afterExecute(
    RuntimePipelineContext<ModuleRuntimeState, DashboardRuntimePatch,
            DashboardRuntimeDiff>
        context,
  ) async {
    // No-op
  }

  @override
  Future<void> run(
    RuntimePipelineContext<ModuleRuntimeState, DashboardRuntimePatch,
            DashboardRuntimeDiff>
        context,
  ) async {
    await beforeExecute(context);
    await execute(context);
    await afterExecute(context);
  }

  @override
  Future<void> execute(
    RuntimePipelineContext<ModuleRuntimeState, DashboardRuntimePatch,
            DashboardRuntimeDiff>
        context,
  ) async {
    var tempState = context.currentState;

    for (final rawEvent in context.events) {
      /// ------------------------------------------------------------
      /// STRICT TYPE SAFETY
      /// ------------------------------------------------------------
      if (rawEvent is! ModuleRuntimeEvent) {
        continue;
      }

      final event = rawEvent;

      /// ------------------------------------------------------------
      /// SAFE RECONCILIATION CALL
      /// ------------------------------------------------------------
      final nextState = await coordinator.reconcile(
        tempState,
        event,
      );

      /// ------------------------------------------------------------
      /// SAFETY: avoid redundant state churn
      /// ------------------------------------------------------------
      if (nextState == tempState) {
        continue;
      }

      tempState = nextState;
    }

    /// ------------------------------------------------------------
    /// FINAL STATE OUTPUT
    /// ------------------------------------------------------------
    context.setNextState(tempState);
  }
}