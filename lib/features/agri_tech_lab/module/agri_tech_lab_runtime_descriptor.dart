/// ============================================================
/// AGRI TECH LAB MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/agri_tech_lab/module/ = module registration
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
/// AGRI TECH LAB MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createAgriTechLabDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'agri_tech_lab',
    displayName: 'AgriTech Lab',
    description: 'Innovation lab for agricultural technology experiments',
    iconKey: 'science',
    route: '/tech-lab',
    displayOrder: 13,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'techlab_experiments',
        displayName: 'Active Experiments',
        sectionKey: 'innovation',
        displayOrder: 1,
        width: 2,
        height: 1,
        iconKey: 'science',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'techlab_sensors',
        displayName: 'Sensor Network',
        sectionKey: 'innovation',
        displayOrder: 2,
        width: 1,
        height: 1,
        iconKey: 'sensors',
        refreshIntervalSeconds: 60,
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'techlab_insights',
        displayName: 'Tech Insights',
        sectionKey: 'innovation',
        displayOrder: 3,
        width: 1,
        height: 1,
        iconKey: 'insights',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'techlab_iot_devices',
        displayName: 'IoT Devices',
        sectionKey: 'innovation',
        displayOrder: 4,
        width: 2,
        height: 1,
        iconKey: 'precision_farming',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'techlab_home_card',
        widgetType: 'card',
        displayName: 'Tech Lab',
        displayOrder: 1,
        iconKey: 'science',
        priority: 4,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'techlab_home_tip',
        widgetType: 'tip',
        displayName: 'Tech Tips',
        displayOrder: 2,
        iconKey: 'tips_and_updates',
        priority: 3,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'techlab_new_experiment',
        label: 'New Experiment',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/tech-lab',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'techlab_connect_sensor',
        label: 'Connect Sensor',
        iconKey: 'sensors',
        displayOrder: 2,
        route: '/tech-lab',
      ),
      QuickActionDescriptor(
        actionKey: 'techlab_view_data',
        label: 'View Sensor Data',
        iconKey: 'analytics',
        displayOrder: 3,
        route: '/tech-lab',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'techlab_notifications',
        displayName: 'AgriTech Lab',
        notificationTypes: [
          'experiment_complete',
          'sensor_alert',
          'iot_disconnected',
          'insight_ready',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'techlab_search',
        displayName: 'AgriTech Lab',
        entityTypes: ['experiments', 'sensors', 'iot_devices', 'data'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'techlab_analytics',
        displayName: 'AgriTech Lab',
        metricKeys: [
          'active_experiments',
          'sensor_count',
          'data_points',
          'iot_devices',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/tech-lab',
        name: 'agri_tech_lab',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'techlab:view',
        displayName: 'View Tech Lab',
        description: 'Ability to view technology lab',
      ),
      PermissionDescriptor(
        permissionKey: 'techlab:experiment',
        displayName: 'Run Experiments',
        description: 'Ability to create experiments',
      ),
    ],
  );
}
