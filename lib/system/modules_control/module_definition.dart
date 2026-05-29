import 'package:flutter/foundation.dart';

/// ============================================================
/// DASHBOARD MODULE DEFINITION (RUNTIME DTO)
/// ============================================================
///
/// Immutable snapshot of a system module adapted for
/// dashboard_engine consumption.
///
/// ❌ NOT a system module definition
/// ❌ NOT a registry entity
/// ❌ NOT a business rule container
/// ============================================================
@immutable
class DashboardModuleDefinition {
  /// System module identifier
  final String moduleKey;

  /// Widget identifier used by renderer
  final String widgetKey;

  /// Whether module is active in system layer
  final bool isEnabled;

  /// Whether module should appear in dashboard UI
  final bool dashboardVisible;

  const DashboardModuleDefinition({
    required this.moduleKey,
    required this.widgetKey,
    required this.isEnabled,
    required this.dashboardVisible,
  });

  /// ============================================================
  /// SAFETY HELPERS (OPTIONAL BUT USEFUL)
  /// ============================================================

  bool get isRenderable => isEnabled && dashboardVisible;

  @override
  String toString() {
    return 'DashboardModuleDefinition('
        'moduleKey: $moduleKey, '
        'widgetKey: $widgetKey, '
        'enabled: $isEnabled, '
        'visible: $dashboardVisible)';
  }
}