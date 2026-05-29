import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/system/modules_control/module_definition.dart';

/// ============================================================
/// MODULE RUNTIME ADAPTER (SYSTEM → DASHBOARD BRIDGE)
/// ============================================================
///
/// PURE TRANSLATION LAYER ONLY.
///
/// Responsibilities:
/// - Convert system modules into engine-safe definitions
/// - Sanitize unsafe/null values
///
/// ❌ MUST NOT:
/// - apply business logic
/// - filter modules
/// - enforce permissions
/// ============================================================
class ModuleRuntimeAdapter {
  const ModuleRuntimeAdapter();

  /// ============================================================
  /// LOAD RAW SYSTEM MODULES (NO FILTERING)
  /// ============================================================
  Future<List<DashboardModuleDefinition>> loadDashboardModules(
    List<SystemModule> systemModules,
  ) async {
    return systemModules
        .map(_toDashboardModule)
        .where((m) => _isValid(m))
        .toList();
  }

  /// ============================================================
  /// PURE TRANSFORMATION ONLY
  /// ============================================================
  DashboardModuleDefinition _toDashboardModule(
    SystemModule module,
  ) {
    return DashboardModuleDefinition(
      moduleKey: module.moduleKey ?? '',
      widgetKey: module.widgetKey ?? '',
      isEnabled: module.isEnabled ?? false,
      dashboardVisible: module.dashboardVisible ?? false,
    );,
      widgetKey: module.moduleKey,
      isEnabled: module.isEnabled,
      dashboardVisible: module.dashboardVisibl===========
  /// ENGINE SAFETY GUARD (MINIMAL SANITIZATION ONLY)
  /// ============================================================
  bool _isValid(DashboardModuleDefinition module) {
    return module.moduleKey.isNotEmpty &&
        module.widgetKey.isNotEmpty;
  }
}