import '../presentation/dashboard/farm_dashboard_composer.dart';
import 'dashboard_widgets_registry.dart';

class FarmManagementRegistry {
  static bool _initialized = false;

  static void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    FarmDashboardWidgetsRegistry.ensureRegistered();
  }
}

