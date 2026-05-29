import '../modules_control/module_contract.dart';

/// ============================================================
/// MODULE REGISTRY (SYSTEM LAYER ONLY)
/// ============================================================
///
/// Pure in-memory registry of AppModule definitions.
///
/// ❌ MUST NOT:
/// - depend on Flutter
/// - return Widgets
/// - use Riverpod
/// - perform rendering
/// ============================================================
class ModuleRegistry {
  static final List<AppModule> _modules = ModuleLoader.loadModules();

  static final Map<String, AppModule> _widgetModuleMap =
      _buildWidgetModuleMap();

  /// All registered modules
  static List<AppModule> getAll() => _modules;

  /// Find module by route
  static AppModule? getByRoute(String route) {
    try {
      return _modules.firstWhere((m) => m.route == route);
    } catch (_) {
      return null;
    }
  }

  /// Filter modules by role
  static List<AppModule> getByRole(String role) {
    return _modules
        .where((m) => m.allowedRoles.contains(role))
        .toList();
  }

  /// Resolve owning module for a widget key
  static AppModule? getModuleByWidgetKey(String widgetKey) {
    return _widgetModuleMap[widgetKey];
  }

  /// Build reverse lookup map (widgetKey → module)
  static Map<String, AppModule> _buildWidgetModuleMap() {
    final map = <String, AppModule>{};

    for (final module in _modules) {
      for (final widgetKey in module.dashboardWidgets) {
        map.putIfAbsent(widgetKey, () => module);
      }
    }

    return map;
  }
}