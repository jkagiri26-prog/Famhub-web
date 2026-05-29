import '../../domain/events/module_runtime_event.dart';
import '../../domain/models/module_runtime_state.dart';

class ModuleRuntimeReconciler {
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

    /// ============================================================
    /// 2. COPY STATE (IMMUTABLE TRANSITION)
    /// ============================================================
    final activeModules = Set<String>.from(currentState.activeModules);
    final disabledModules = Set<String>.from(currentState.disabledModules);
    final maintenanceModules = Set<String>.from(currentState.maintenanceModules);

    /// ============================================================
    /// 3. CORE RECONCILIATION RULES (DETERMINISTIC)
    /// ============================================================
    if (enabled) {
      activeModules.add(moduleKey);
      disabledModules.remove(moduleKey);
    } else {
      activeModules.remove(moduleKey);
      disabledModules.add(moduleKey);
    }

    /// ============================================================
    /// 4. INVARIANT ENFORCEMENT (IMPORTANT FIX)
    /// ============================================================
    if (maintenance) {
      maintenanceModules.add(moduleKey);

      /// A module in maintenance should NEVER be active
      activeModules.remove(moduleKey);
    } else {
      maintenanceModules.remove(moduleKey);
    }

    /// ============================================================
    /// 5. FINAL STATE
    /// ============================================================
    return currentState.copyWith(
      activeModules: activeModules,
      disabledModules: disabledModules,
      maintenanceModules: maintenanceModules,
      lastSyncedAt: DateTime.now(),
    );
  }
}