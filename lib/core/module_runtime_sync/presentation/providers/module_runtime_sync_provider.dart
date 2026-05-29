import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/coordinators/module_runtime_sync_coordinator.dart';
import '../../../dashboard_engine/application/reconciliation/dashboard_runtime_reconciler.dart';
import '../../domain/models/module_runtime_state.dart';

/// ============================================================
/// MODULE RUNTIME SYNC STATE PROVIDER (HARDENED CORE STATE)
/// ============================================================

final moduleRuntimeSyncProvider =
    StateNotifierProvider<ModuleRuntimeSyncNotifier, ModuleRuntimeState>(
  (ref) => ModuleRuntimeSyncNotifier(),
);

class ModuleRuntimeSyncNotifier extends StateNotifier<ModuleRuntimeState> {
  ModuleRuntimeSyncNotifier() : super(ModuleRuntimeState.initial());

  /// ============================================================
  /// STRICT STATE REPLACEMENT (IMMUTABLE CONTRACT)
  /// ============================================================
  void updateState(ModuleRuntimeState nextState) {
    if (nextState == state) return;

    state = nextState;
  }

  /// ============================================================
  /// SAFE RESET (OPTIONAL BUT IMPORTANT FOR RECOVERY)
  /// ============================================================
  void reset() {
    state = ModuleRuntimeState.initial();
  }
}

/// ============================================================
/// COORDINATOR PROVIDER (UNCHANGED BUT ISOLATED BY DESIGN)
/// ============================================================

final moduleRuntimeSyncCoordinatorProvider =
    Provider<ModuleRuntimeSyncCoordinator>((ref) {
  return ModuleRuntimeSyncCoordinator(
    reconciler: ModuleRuntimeReconciler(),
  );
});