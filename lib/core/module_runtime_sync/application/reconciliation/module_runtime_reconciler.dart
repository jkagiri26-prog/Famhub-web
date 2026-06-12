import 'package:famhub_app/core/module_runtime_sync/domain/events/module_runtime_event.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';

/// ============================================================
/// MODULE RUNTIME RECONCILER
/// ============================================================
///
/// PURE STATE MACHINE:
/// Given current state + event → produces next state.
///
/// This is the deterministic core of the reconciliation pipeline.
/// No side effects. No I/O. No timestamp dependence.
/// ============================================================
class ModuleRuntimeReconciler {
  const ModuleRuntimeReconciler();

  /// ============================================================
  /// RECONCILE — PURE STATE TRANSITION
  /// ============================================================
  ///
  /// Transforms ModuleRuntimeState deterministically based on
  /// the incoming event's payload fields:
  ///   - module_key: the module identifier
  ///   - is_enabled: toggle active/inactive
  ///   - maintenance_mode: toggle maintenance state
  ///
  Future<ModuleRuntimeState> reconcile(
    ModuleRuntimeState currentState,
    ModuleRuntimeEvent event,
  ) async {
    final payload = event.payload;

    final moduleKeyRaw = payload['module_key'];

    if (moduleKeyRaw == null) {
      return currentState;
    }

    final moduleKey = moduleKeyRaw.toString().trim();

    if (moduleKey.isEmpty) {
      return currentState;
    }

    final enabled = payload['is_enabled'] == true;
    final maintenance = payload['maintenance_mode'] == true;

    // ============================================================
    // STATE COPY
    // ============================================================

    final activeModules = Set<String>.from(currentState.activeModules);

    final disabledModules = Set<String>.from(currentState.disabledModules);

    final maintenanceModules = Set<String>.from(
      currentState.maintenanceModules,
    );

    // ============================================================
    // STATE TRANSITION
    // ============================================================

    if (enabled) {
      activeModules.add(moduleKey);
      disabledModules.remove(moduleKey);
    } else {
      activeModules.remove(moduleKey);
      disabledModules.add(moduleKey);
    }

    if (maintenance) {
      maintenanceModules.add(moduleKey);
      activeModules.remove(moduleKey);
    } else {
      maintenanceModules.remove(moduleKey);
    }

    // ============================================================
    // FINAL STATE
    // ============================================================

    return currentState.copyWith(
      activeModules: activeModules,
      disabledModules: disabledModules,
      maintenanceModules: maintenanceModules,
      lastSyncedAt: DateTime.now(),
    );
  }
}
