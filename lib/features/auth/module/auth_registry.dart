import '../../../../dashboard/registry/dashboard_registry.dart';

class AuthDashboardWidgetsRegistry {
  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;

    // Auth module doesn't register dashboard widgets
  }
}
