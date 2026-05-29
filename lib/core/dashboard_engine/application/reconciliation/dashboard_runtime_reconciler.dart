import '../../../module_runtime_sync/domain/models/module_runtime_state.dart';

import 'dashboard_runtime_dependency_resolver.dart';
import 'dashboard_runtime_diff.dart';
import 'dashboard_runtime_patch.dart';
import 'dashboard_runtime_refresh_policy.dart';

/// ============================================================
/// DASHBOARD RUNTIME RECONCILER (CLEAN ARCHITECTURE)
/// ============================================================
/// Responsibilities:
/// 1. Generate diff (pure comparison)
/// 2. Resolve dependencies (graph expansion)
/// 3. Generate deterministic patch (UI actions only)
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
  // 2. DEPENDENCY RESOLUTION (SEPARATE STEP)
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
  // 3. PATCH GENERATION (PURE OUTPUT)
  // ============================================================
  DashboardRuntimePatch generatePatch(
    ResolvedDashboardDiff diff,
  ) {
    final actions = <DashboardRuntimePatchAction>[];

    // ------------------------------------------------------------
    // Added modules → refresh zone
    // ------------------------------------------------------------
    for (final module in diff.base.addedModules) {
      actions.add(
        DashboardRuntimePatchAction(
          type: DashboardPatchActionType.refreshZone,
          target: module,
        ),
      );
    }

    // ------------------------------------------------------------
    // Removed modules → remove widget
    // ------------------------------------------------------------
    for (final module in diff.base.removedModules) {
      actions.add(
        DashboardRuntimePatchAction(
          type: DashboardPatchActionType.removeWidget,
          target: module,
        ),
      );
    }

    // ------------------------------------------------------------
    // Maintenance changes → refresh zone
    // ------------------------------------------------------------
    for (final module in diff.base.maintenanceChangedModules) {
      actions.add(
        DashboardRuntimePatchAction(
          type: DashboardPatchActionType.refreshZone,
          target: module,
        ),
      );
    }

    // ------------------------------------------------------------
    // Dependency invalidation → cascade refresh
    // ------------------------------------------------------------
    for (final module in diff.invalidatedModules) {
      actions.add(
        DashboardRuntimePatchAction(
          type: DashboardPatchActionType.invalidateDependency,
          target: module,
        ),
      );
    }

    // ------------------------------------------------------------
    // Navigation refresh (policy-driven)
    // ------------------------------------------------------------
    if (diff.shouldRefreshNavigation) {
      actions.add(
        const DashboardRuntimePatchAction(
          type: DashboardPatchActionType.refreshNavigation,
          target: 'global_navigation',
        ),
      );
    }

    return DashboardRuntimePatch(actions: actions);
  }
}

/// ============================================================
/// RESOLVED DIFF MODEL (NEW REQUIRED LAYER)
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