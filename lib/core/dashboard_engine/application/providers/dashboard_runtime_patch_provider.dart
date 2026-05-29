import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/reconciliation/dashboard_runtime_dependency_resolver.dart';
import '../../application/reconciliation/dashboard_runtime_patch.dart';
import '../../application/reconciliation/dashboard_runtime_reconciler.dart';
import '../../application/reconciliation/dashboard_runtime_refresh_policy.dart';

final dashboardRuntimePatchProvider =
    StateNotifierProvider<
      DashboardRuntimePatchNotifier,
      DashboardRuntimePatch
    >(
      (ref) => DashboardRuntimePatchNotifier(),
    );

class DashboardRuntimePatchNotifier
    extends StateNotifier<DashboardRuntimePatch> {
  DashboardRuntimePatchNotifier()
    : super(
        const DashboardRuntimePatch(
          actions: [],
        ),
      );

  void applyPatch(
    DashboardRuntimePatch patch,
  ) {
    state = patch;
  }

  void clear() {
    state = const DashboardRuntimePatch(
      actions: [],
    );
  }
}

final dashboardRuntimeReconcilerProvider =
    Provider<DashboardRuntimeReconciler>(
      (ref) {
        return DashboardRuntimeReconciler(
          refreshPolicy:
              const DashboardRuntimeRefreshPolicy(),
          dependencyResolver:
              const DashboardRuntimeDependencyResolver(),
        );
      },
    );