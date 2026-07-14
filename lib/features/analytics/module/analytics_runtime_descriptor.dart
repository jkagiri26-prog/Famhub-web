/// ============================================================
/// ANALYTICS MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/analytics/module/ = module registration
///
/// ✅ Responsibilities:
///   - Expose ModuleRuntimeDescriptor for the composition engine
///   - Pure descriptor — NO widget trees, NO rendering logic
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Backend (system.modules) is the ONLY source of truth
///   - This descriptor is only the static contribution catalog
///   - Visibility is governed by Context Engine + RuntimeFeatureFlags
/// ============================================================
library;

import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';

/// ============================================================
/// ANALYTICS MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createAnalyticsDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'analytics',
    displayName: 'Analytics',
    description: 'Data analytics and insights dashboard',
    iconKey: 'analytics',
    route: '/analytics',
    displayOrder: 3,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        moduleKey: 'analytics',
        widgetKey: 'analytics_overview',
        displayName: 'Analytics Overview',
        sectionKey: 'analytics',
        displayOrder: 1,
        width: 2,
        height: 1,
        iconKey: 'dashboard',
        refreshIntervalSeconds: 300,
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'analytics',
        widgetKey: 'analytics_charts',
        displayName: 'Performance Charts',
        sectionKey: 'analytics',
        displayOrder: 2,
        width: 2,
        height: 1,
        iconKey: 'bar_chart',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'analytics',
        widgetKey: 'analytics_reports',
        displayName: 'Saved Reports',
        sectionKey: 'analytics',
        displayOrder: 3,
        width: 1,
        height: 1,
        iconKey: 'description',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'analytics',
        widgetKey: 'analytics_trends',
        displayName: 'Trend Analysis',
        sectionKey: 'analytics',
        displayOrder: 4,
        width: 1,
        height: 1,
        iconKey: 'trending_up',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'analytics_home_card',
        widgetType: 'card',
        displayName: 'Analytics Summary',
        displayOrder: 1,
        iconKey: 'analytics',
        priority: 5,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'analytics_home_insight',
        widgetType: 'ai_suggestion',
        displayName: 'Key Insights',
        displayOrder: 2,
        iconKey: 'insights',
        priority: 6,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'analytics_create_report',
        label: 'Create Report',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/analytics',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'analytics_export',
        label: 'Export Data',
        iconKey: 'file_download',
        displayOrder: 2,
        route: '/analytics',
      ),
      QuickActionDescriptor(
        actionKey: 'analytics_scheduled',
        label: 'Scheduled Reports',
        iconKey: 'schedule',
        displayOrder: 3,
        route: '/analytics',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'analytics_notifications',
        displayName: 'Analytics',
        notificationTypes: [
          'report_ready',
          'anomaly_detected',
          'target_milestone',
          'scheduled_report',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'analytics_search',
        displayName: 'Analytics',
        entityTypes: ['reports', 'charts', 'metrics', 'insights'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'analytics_analytics',
        displayName: 'Analytics',
        metricKeys: [
          'report_count',
          'query_count',
          'export_count',
          'schedule_count',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/analytics',
        name: 'analytics',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'analytics:view',
        displayName: 'View Analytics',
        description: 'Ability to view analytics dashboard',
      ),
      PermissionDescriptor(
        permissionKey: 'analytics:create',
        displayName: 'Create Reports',
        description: 'Ability to create custom reports',
      ),
      PermissionDescriptor(
        permissionKey: 'analytics:export',
        displayName: 'Export Data',
        description: 'Ability to export analytics data',
      ),
    ],
  );
}
