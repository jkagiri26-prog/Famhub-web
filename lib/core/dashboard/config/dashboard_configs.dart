import '../../../features/dashboard/models/dashboard_config.dart';
import '../../../features/dashboard/models/dashboard_widget.dart';

/// ============================================================
/// DASHBOARD CONFIG SEED (LEGACY / FALLBACK ONLY)
/// ============================================================
///
/// This is NOT part of the live dashboard system.
///
/// Live system uses:
/// - system.dashboard_descriptors (backend)
/// - DashboardRendererService
///
/// This file is only for:
/// - initial onboarding screens
/// - fallback dashboards when backend is empty
/// - development scaffolding
/// ============================================================

class DashboardConfigs {
  static DashboardConfig getConfig(String? role) {
    final r = role ?? 'guest';

    /// Minimal safe fallback only
    final base = <DashboardWidgetConfig>[
      const DashboardWidgetConfig(id: 'kpi', order: 0, flex: 1),
      const DashboardWidgetConfig(id: 'activity', order: 1, flex: 1),
      const DashboardWidgetConfig(id: 'actions', order: 2, flex: 1),
    ];

    return DashboardConfig(
      role: r,
      widgets: base,
    );
  }
}