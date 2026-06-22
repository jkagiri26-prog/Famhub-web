import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_dependency_resolver.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_patch.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_reconciler.dart';
import 'package:famhub_app/core/dashboard_engine/application/reconciliation/dashboard_runtime_refresh_policy.dart';

final dashboardRuntimePatchProvider =
    NotifierProvider<
      DashboardRuntimePatchNotifier,
      DashboardRuntimePatch
    >(
      DashboardRuntimePatchNotifier.new,
    );

class DashboardRuntimePatchNotifier
    extends Notifier<DashboardRuntimePatch> {
  @override
  DashboardRuntimePatch build() {
    return DashboardRuntimePatch(
      actions: [],
    );
  }

  void applyPatch(
    DashboardRuntimePatch patch,
  ) {
    state = patch;
  }

  /// Applies a refresh signal identified by patchId
  void applyPatchId(String patchId) {
    state = DashboardRuntimePatch(
      actions: [
        DashboardRuntimePatchAction(
          type: DashboardPatchActionType.refreshNavigation,
          target: patchId,
        ),
      ],
    );
  }

  void clear() {
    state = DashboardRuntimePatch(
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
