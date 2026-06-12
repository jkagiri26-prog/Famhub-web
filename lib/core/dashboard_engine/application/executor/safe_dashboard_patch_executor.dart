import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/trace_collector_provider.dart';
import 'package:famhub_app/core/dashboard_engine/application/telemetry/dashboard_trace_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/state/widget_state_store.dart';

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
    final widgetStore = ref.read(widgetStateStoreProvider);

    int processed = 0;
    int failed = 0;
    final errors = <PatchActionError>[];

    // ============================================================
    // STAGED EXECUTION BUFFER (FOR ATOMIC ROLLBACK)
    // ============================================================
    final appliedActions = <DashboardPatchAction>[];
    final savedStates = <String, WidgetStateModel>{};

    try {
      tracer.log(DashboardTraceEvent(
        id: patch.id,
        stage: TraceStage.queued,
        timestamp: DateTime.now(),
        context: {'actionCount': patch.actions.length},
      ));

      final Set<String> affectedWidgets = {};

      // ============================================================
      // EXECUTION PHASE (COMPOSITION-AWARE, ROLLBACK-SAFE)
      // ============================================================
      for (final action in patch.actions) {
        try {
          switch (action.type) {
            case DashboardPatchActionType.refreshZone:
              affectedWidgets.add(action.target);
              break;

            case DashboardPatchActionType.removeWidget:
              // Save state BEFORE removal for potential rollback
              final existing = widgetStore.get(action.target);
              if (existing != null) {
                savedStates[action.target] = existing;
              }
              widgetStore.remove(action.target);
              affectedWidgets.add(action.target);
              break;

            case DashboardPatchActionType.refreshNavigation:
              _refreshNavigation();
              break;

            case DashboardPatchActionType.invalidateDependency:
              affectedWidgets.add(action.target);
              break;

            case DashboardPatchActionType.invalidateModules:
              final modules = action.payload?['modules'];
              if (modules is List) {
                affectedWidgets.addAll(modules.cast<String>());
              }
              break;
          }

          appliedActions.add(action);
          processed++;
        } catch (e) {
          failed++;

          errors.add(PatchActionError(
            actionId: action.target,
            zoneId: 'composition',
            reason: PatchActionFailureReason.unknown,
            message: e.toString(),
            timestamp: DateTime.now(),
            retriable: false,
          ));

          // STOP execution immediately on failure — no partial commit
          break;
        }
      }

      // ============================================================
      // COMMIT ONLY IF ALL ACTIONS SUCCEEDED
      // ============================================================
      if (failed == 0) {
        _invalidateComposition(affectedWidgets.toList());
      } else {
        // Rollback previously applied actions in reverse order
        _rollback(appliedActions, savedStates, widgetStore);
      }

      tracer.log(DashboardTraceEvent(
        id: patch.id,
        stage: failed == 0 ? TraceStage.executed : TraceStage.error,
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
      // Catastrophic failure — attempt rollback of anything applied
      _rollback(appliedActions, savedStates, widgetStore);

      return SafePatchExecutionResult(
        actionsProcessed: processed,
        actionsFailed: patch.actions.length - processed,
        errors: [
          PatchActionError(
            actionId: 'batch',
            zoneId: 'composition',
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

  // ============================================================
  // ATOMIC ROLLBACK (REVERSE ORDER)
  // ============================================================
  void _rollback(
    List<DashboardPatchAction> appliedActions,
    Map<String, WidgetStateModel> savedStates,
    WidgetStateStore widgetStore,
  ) {
    for (final action in appliedActions.reversed) {
      switch (action.type) {
        case DashboardPatchActionType.removeWidget:
          final saved = savedStates[action.target];
          if (saved != null) {
            widgetStore.restore(action.target, saved);
          }
          break;
        default:
          break;
      }
    }
  }

  // ============================================================
  // COMPOSITION INVALIDATION (NEW ARCHITECTURE HOOK)
  // ============================================================
  void _invalidateComposition(List<String> affectedWidgets) {
    /// This triggers:
    /// DashboardCompositionEngine rebuild →
    /// CompositionSnapshot update →
    /// snapshot_diff →
    /// DashboardRenderer update
  }

  void _refreshNavigation() {
    /// handled by router/navigation layer
  }
}