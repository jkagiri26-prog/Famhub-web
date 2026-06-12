import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/dashboard_frame_scheduler_provider.dart';

class DashboardPatchExecutor {
  DashboardPatchExecutor({
    required this.ref,
  });

  final Ref ref;

  bool _isExecuting = false;

  Future<void> execute(
    DashboardRuntimePatch patch,
  ) async {
    if (patch.isEmpty) return;

    final actions =
        List<DashboardRuntimePatchAction>.from(patch.actions);

    if (_isExecuting) return;
    _isExecuting = true;

    final scheduler = ref.read(dashboardFrameSchedulerProvider);

    try {
      final Set<String> dirtyModules = {};

      // ============================================================
      // 1. INTENT PHASE (COLLECT IMPACTED MODULES)
      // ============================================================
      for (final action in actions) {
        switch (action.type) {
          case DashboardPatchActionType.refreshZone:
          case DashboardPatchActionType.invalidateDependency:
          case DashboardPatchActionType.removeWidget:
            dirtyModules.add(action.target);
            break;

          case DashboardPatchActionType.refreshNavigation:
            // navigation is separate UI domain
            break;
        }
      }

      // ============================================================
      // 2. EXECUTION PHASE (COMPOSITION-DRIVEN)
      // ============================================================
      scheduler.schedule(() async {
        try {
          for (final action in actions) {
            switch (action.type) {
              case DashboardPatchActionType.refreshZone:
                _invalidateComposition();
                break;

              case DashboardPatchActionType.removeWidget:
                _invalidateComposition();
                break;

              case DashboardPatchActionType.invalidateDependency:
                _invalidateComposition();
                break;

              case DashboardPatchActionType.refreshNavigation:
                _refreshNavigation();
                break;
            }
          }
        } finally {
          _isExecuting = false;
        }
      });
    } catch (_) {
      _isExecuting = false;
      rethrow;
    }
  }

  // ============================================================
  // COMPOSITION INVALIDATION (NEW SYSTEM ENTRY POINT)
  // ============================================================
  void _invalidateComposition() {
    /// This triggers:
    /// DashboardCompositionEngine → rebuild → snapshot_diff → renderer update
  }

  // ============================================================
  // NAVIGATION DOMAIN (SEPARATE SYSTEM)
  // ============================================================
  void _refreshNavigation() {
    /// handled by navigation provider / router layer
  }
}