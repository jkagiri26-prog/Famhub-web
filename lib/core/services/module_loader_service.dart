import 'package:famhub_app/core/modules/domain/models/dashboard_module_definition.dart';
import 'package:famhub_app/core/dashboard_engine/infrastructure/adapters/module_runtime_adapter.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';

/// ============================================================
/// MODULE LOADER SERVICE (RUNTIME LAYER)
/// ============================================================
///
/// Core service responsible for runtime module loading.
/// Belongs in core/services/ — NOT in system/registry/
/// and NOT in system/modules_control/.
///
/// ✅ Correct Location:
///   core/services/ = runtime service layer
///
/// ❌ Incorrect Previous Location:
///   system/modules_control/ = governance layer (not runtime)
///   system/registry/ = blueprint layer (not runtime)
/// ============================================================
class DashboardModuleLoader {
  final ModuleRuntimeAdapter adapter;

  DashboardModuleLoader({
    required this.adapter,
  });

  /// Load modules from system layer (no transformation)
  Future<List<DashboardModuleDefinition>> load(
    List<SystemModule> systemModules,
  ) {
    return adapter.loadDashboardModules(systemModules);
  }
}