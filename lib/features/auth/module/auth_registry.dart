import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_builder_registry.dart';

/// ============================================================
/// AUTH WIDGET REGISTRATION (PRESENTATION LAYER ONLY)
/// ============================================================
///
/// Registers auth-specific dashboard widgets with the
/// WidgetBuilderRegistry for use by the dashboard renderer.
///
/// 🧠 LOCATION CONTEXT:
///   features/auth/module/ = module configuration
///   dashboard_engine/presentation/builders/ = widget resolution
/// ============================================================
class AuthDashboardWidgetsRegistry {
  static bool _registered = false;

  static void ensureRegistered() {
    if (_registered) return;
    _registered = true;

    // Auth module doesn't register dashboard widgets currently
    // Future widget registrations should use:
    // WidgetBuilderRegistry.register(
    //   widgetKey: 'auth_...',
    //   builder: () => const SomeAuthWidget(),
    // );
  }
}
