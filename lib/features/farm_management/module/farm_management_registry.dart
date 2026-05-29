import '../presentation/dashboard/farm_dashboard_composer.dart';

/// ============================================================
/// FARM MANAGEMENT REGISTRY
/// ============================================================
/// Legacy registry - maintained for compatibility.
/// Dashboard widgets are now declared in FarmManagementModule.dashboardWidgets
/// and resolved through ModuleRegistry.
/// ============================================================

class FarmManagementRegistry {
  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    // Widget registration moved to ModuleRegistry via FarmManagementModule.dashboardWidgets
    // No longer need separate dashboard widget registration
  }
}

