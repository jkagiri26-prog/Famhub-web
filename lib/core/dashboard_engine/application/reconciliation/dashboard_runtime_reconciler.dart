import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';

import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_dependency_resolver.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_diff.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_refresh_policy.dart';

/// ============================================================
/// DASHBOARD RUNTIME RECONCILER (CLEAN ARCHITECTURE)
/// ============================================================
/// Responsibilities:
/// 1. Generate diff (pure comparison)
/// 2. Resolve dependencies (graph expansion)
/// 3. Generate INVALIDATION INTENT (NOT UI ACTIONS)
class DashboardRuntimeReconciler {
  DashboardRuntimeReconciler({
    required this.refreshPolicy,
    required this.dependencyResolver,
  });

  final DashboardRuntimeRefreshPolicy refreshPolicy;
  final DashboardRuntimeDependencyResolver dependencyResolver;

  // ============================================================
  // 1. DIFF GENERATION (PURE FUNCTION)
  // ============================================================
  DashboardRuntimeDiff generateDiff({
    required ModuleRuntimeState previous,
    required ModuleRuntimeState next,
  }) {
    final addedModules =
        next.activeModules.difference(previous.activeModules);

    final removedModules =
        previous.activeModules.difference(next.activeModules);

    final maintenanceChangedModules =
        next.maintenanceModules.symmetricDifference(
      previous.maintenanceModules,
    );

    final hasChanges = addedModules.isNotEmpty ||
        removedModules.isNotEmpty ||
        maintenanceChangedModules.isNotEmpty;

    return DashboardRuntimeDiff(
      addedModules: addedModules,
      removedModules: removedModules,
      maintenanceChangedModules: maintenanceChangedModules,
      requiresRefresh: hasChanges,
    );
  }

  // ============================================================
  // 2. DEPENDENCY RESOLUTION (PURE GRAPH EXPANSION)
  // ============================================================
  ResolvedDashboardDiff resolveDependencies(
    DashboardRuntimeDiff diff,
  ) {
    final invalidatedModules =
        dependencyResolver.resolveInvalidatedModules(
      diff.removedModules,
    );

    final shouldRefreshNavigation =
        refreshPolicy.shouldRefreshNavigation(
      hasModuleChanges: diff.requiresRefresh,
    );

    return ResolvedDashboardDiff(
      base: diff,
      invalidatedModules: invalidatedModules,
      shouldRefreshNavigation: shouldRefreshNavigation,
    );
  }

  // ============================================================
  // 3. INVALIDATION INTENT (NO UI ACTIONS)
  // ============================================================
  DashboardRuntimePatch generatePatch(
    ResolvedDashboardDiff diff,
  ) {
    final affectedModules = <String>{};

    // aggregate all invalidation sources
    affectedModules.addAll(diff.base.addedModules);
    affectedModules.addAll(diff.base.removedModules);
    affectedModules.addAll(diff.base.maintenanceChangedModules);
    affectedModules.addAll(diff.invalidatedModules);

    return DashboardRuntimePatch(
      actions: [
        DashboardRuntimePatchAction(
          type: DashboardPatchActionType.invalidateModules,
          target: 'composition_engine',
          payload: {
            'modules': affectedModules.toList(),
          },
        ),

        if (diff.shouldRefreshNavigation)
          const DashboardRuntimePatchAction(
            type: DashboardPatchActionType.refreshNavigation,
            target: 'global_navigation',
          ),
      ],
    );
  }
}

/// ============================================================
/// RESOLVED DIFF MODEL
/// ============================================================
class ResolvedDashboardDiff {
  final DashboardRuntimeDiff base;
  final Set<String> invalidatedModules;
  final bool shouldRefreshNavigation;

  ResolvedDashboardDiff({
    required this.base,
    required this.invalidatedModules,
    required this.shouldRefreshNavigation,
  });
}