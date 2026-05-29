import 'package:flutter/widgets.dart';

/// ============================================================
/// DASHBOARD WIDGET BUILDER REGISTRY
/// ============================================================
///
/// Presentation-layer ONLY registry that maps widgetKeys
/// to Flutter widget builders.
///
/// Used strictly by dashboard_renderer.
///
/// ❌ NOT a service locator
/// ❌ NOT a module registry
/// ❌ NOT a dependency injection system
/// ============================================================
typedef DashboardWidgetBuilder = Widget Function();

class WidgetBuilderRegistry {
  /// Internal registry map
  static final Map<String, DashboardWidgetBuilder> _builders = {};

  /// ============================================================
  /// REGISTER WIDGET BUILDER
  /// ============================================================
  static void register({
    required String widgetKey,
    required DashboardWidgetBuilder builder,
  }) {
    // Prevent accidental overwrite in production flow
    if (_builders.containsKey(widgetKey)) {
      throw Exception(
        'WidgetBuilder already registered for key: $widgetKey',
      );
    }

    _builders[widgetKey] = builder;
  }

  /// ============================================================
  /// RESOLVE WIDGET BUILDER
  /// ============================================================
  static DashboardWidgetBuilder? resolve(
    String widgetKey,
  ) {
    return _builders[widgetKey];
  }

  /// ============================================================
  /// DEBUG / SAFETY HELPERS
  /// ============================================================
  static bool isRegistered(String widgetKey) {
    return _builders.containsKey(widgetKey);
  }

  static void clear() {
    _builders.clear();
  }
}