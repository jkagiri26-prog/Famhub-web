import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reconciliation/dashboard_runtime_patch.dart';
import '../providers/trace_collector_provider.dart';
import '../../application/telemetry/dashboard_trace_event.dart';
import '../providers/dashboard_zone_controller_provider.dart';
import '../providers/dashboard_zone_render_provider.dart';
import '../state/widget_state_store.dart';

enum PatchActionFailureReason {
  schedulerOverloaded,
  invalidPatch,
  nullStateError,
  unknown,
}

class SafePatchExecutionResult {
  final int actionsProcessed;
  final int actionsFailed;
  final List<PatchActionError> errors;

  const SafePatchExecutionResult({
    required this.actionsProcessed,
    required this.actionsFailed,
    required this.errors,
  });

  bool get isSuccess => actionsFailed == 0;
}

class PatchActionError {
  final String actionId;
  final String zoneId;
  final PatchActionFailureReason reason;
  final String message;
  final DateTime timestamp;
  final bool retriable;

  const PatchActionError({
    required this.actionId,
    required this.zoneId,
    required this.reason,
    required this.message,
    required this.timestamp,
    required this.retriable,
  });
}

class SafeDashboardPatchExecutor {
  SafeDashboardPatchExecutor({
    required this.ref,
  });

  final Ref ref;

  bool _isExecuting = false;

  Future<SafePatchExecutionResult> executeSafely(
    DashboardRuntimePatch patch,
  ) async {
    if (patch.isEmpty) {
      return const SafePatchExecutionResult(
        actionsProcessed: 0,
        actionsFailed: 0,
        errors: [],
      );
    }

    if (_isExecuting) {
      return SafePatchExecutionResult(
        actionsProcessed: 0,
        actionsFailed: patch.actions.length,
        errors: [
          PatchActionError(
            actionId: 'batch',
            zoneId: 'global',
            reason: PatchActionFailureReason.schedulerOverloaded,
            message: 'Re-entrancy blocked',
            timestamp: DateTime.now(),
            retriable: true,
          )
        ],
      );
    }

    _isExecuting = true;

    final tracer = ref.read(traceCollectorProvider);

    final zoneController =
        ref.read(dashboardZoneControllerProvider.notifier);

    final zoneRender =
        ref.read(dashboardZoneRenderProvider.notifier);

    final widgetStore = ref.read(widgetStateStoreProvider);

    int processed = 0;
    int failed = 0;
    final errors = <PatchActionError>[];

    try {
      tracer.log(DashboardTraceEvent(
        id: patch.hashCode.toString(),
        stage: TraceStage.patchExecutionStarted,
        timestamp: DateTime.now(),
        context: {'actionCount': patch.actions.length},
      ));

      for (final action in patch.actions) {
        try {
          switch (action.type) {
            case DashboardPatchActionType.refreshZone:
              zoneController.refreshZone(action.target);
              break;

            case DashboardPatchActionType.removeWidget:
              zoneController.removeWidget(action.target);
              widgetStore.removeInternal(action.target);
              break;

            case DashboardPatchActionType.refreshNavigation:
              zoneController.refreshNavigation();
              break;

            case DashboardPatchActionType.invalidateDependency:
              zoneController.invalidateWidget(action.target);
              break;
          }

          processed++;
        } catch (e) {
          failed++;

          errors.add(PatchActionError(
            actionId: action.target,
            zoneId: action.target,
            reason: PatchActionFailureReason.unknown,
            message: e.toString(),
            timestamp: DateTime.now(),
            retriable: false,
          ));
        }
      }

      zoneRender.markZonesDirty(
        patch.affectedTargets(),
      );

      tracer.log(DashboardTraceEvent(
        id: patch.hashCode.toString(),
        stage: TraceStage.patchExecutionCompleted,
        timestamp: DateTime.now(),
        context: {
          'processed': processed,
          'failed': failed,
        },
      ));

      return SafePatchExecutionResult(
        actionsProcessed: processed,
        actionsFailed: failed,
        errors: errors,
      );
    } catch (e) {
      return SafePatchExecutionResult(
        actionsProcessed: processed,
        actionsFailed: patch.actions.length - processed,
        errors: [
          PatchActionError(
            actionId: 'batch',
            zoneId: 'global',
            reason: PatchActionFailureReason.unknown,
            message: e.toString(),
            timestamp: DateTime.now(),
            retriable: false,
          )
        ],
      );
    } finally {
      _isExecuting = false;
    }
  }
}