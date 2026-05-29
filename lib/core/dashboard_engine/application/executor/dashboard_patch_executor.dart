import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reconciliation/dashboard_runtime_patch.dart';

import '../providers/dashboard_zone_controller_provider.dart';
import '../providers/dashboard_zone_render_provider.dart';

import '../providers/dashboard_frame_scheduler_provider.dart';

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

    /// ============================================================
    /// HARD IMMUTABLE SNAPSHOT
    /// ============================================================
    final actions =
        List<DashboardRuntimePatchAction>.from(
      patch.actions,
    );

    /// ============================================================
    /// HARD RE-ENTRANCY GUARD
    /// ============================================================
    if (_isExecuting) return;

    _isExecuting = true;

    final zoneController =
        ref.read(
      dashboardZoneControllerProvider.notifier,
    );

    final zoneRender =
        ref.read(
      dashboardZoneRenderProvider.notifier,
    );

    final scheduler =
        ref.read(
      dashboardFrameSchedulerProvider,
    );

    final Set<String> dirtyZones = {};

    try {
      // =========================================================
      // 1. INTENT PHASE (PURE)
      // =========================================================
      for (final action in actions) {
        switch (action.type) {
          case DashboardPatchActionType.refreshZone:
          case DashboardPatchActionType.invalidateDependency:
          case DashboardPatchActionType.removeWidget:
            dirtyZones.add(action.target);
            break;

          case DashboardPatchActionType.refreshNavigation:
            dirtyZones.add('navigation');
            break;
        }
      }

      // =========================================================
      // 2. FRAME EXECUTION
      // =========================================================
      try {
        scheduler.schedule(() async {
          try {
            // ---------------------------------------------------
            // ZONE OPERATIONS
            // ---------------------------------------------------
            for (final action in actions) {
              switch (action.type) {
                case DashboardPatchActionType.refreshZone:
                  zoneController.refreshZone(
                    action.target,
                  );
                  break;

                case DashboardPatchActionType.removeWidget:
                  zoneController.removeWidget(
                    action.target,
                  );
                  break;

                case DashboardPatchActionType.refreshNavigation:
                  zoneController.refreshNavigation();
                  break;

                case DashboardPatchActionType.invalidateDependency:
                  zoneController.invalidateWidget(
                    action.target,
                  );
                  break;
              }
            }

            // ---------------------------------------------------
            // RENDER INVALIDATION
            // ---------------------------------------------------
            if (dirtyZones.isNotEmpty) {
              zoneRender.markZonesDirty(
                dirtyZones.toList(),
              );
            }
          } finally {
            // ---------------------------------------------------
            // GUARANTEED RELEASE
            // ---------------------------------------------------
            _isExecuting = false;
          }
        });
      } catch (_) {
        _isExecuting = false;
        rethrow;
      }
    } catch (_) {
      _isExecuting = false;
    }
  }
}