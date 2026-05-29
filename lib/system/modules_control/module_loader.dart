import '../modules_control/module_definition.dart';
import '../../core/dashboard_engine/infrastructure/adapters/module_runtime_adapter.dart';

/// ============================================================
/// DASHBOARD MODULE LOADER
/// ============================================================
///
/// Thin engine-facing wrapper over ModuleRuntimeAdapter.
///
/// Responsibility:
/// - delegate module loading to system adapter
/// - keep engine isolation from system layer
///
/// ❌ MUST NOT:
/// - filter modules
/// - apply business logic
/// - decide visibility rules
/// ============================================================
class DashboardModuleLoader {
  final ModuleRuntimeAdapter adapter;

  DashboardModuleLoader({
    required this.adapter,
  });

  /// Load modules from system layer (no transformation)
  Future<List<DashboardModuleDefinition>> load({
    required String device,
    String? role,
    String? entityId,
  }) {
    return adapter.loadDashboardModules(
      device: device,
      role: role,
      entityId: entityId,
    );
  }
}