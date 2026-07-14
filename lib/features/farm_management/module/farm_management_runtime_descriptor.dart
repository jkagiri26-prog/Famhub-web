/// ============================================================
/// FARM MANAGEMENT MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/module/ = module registration
///
/// ✅ Responsibilities:
///   - Expose ModuleRuntimeDescriptor for the composition engine
///   - Define dashboard widgets, home widgets, quick actions,
///     notification providers, search providers, analytics providers,
///     routes, and permissions
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
/// FARM MANAGEMENT MODULE DESCRIPTOR
/// ============================================================
///
/// Registers all farm management contributions for the runtime engine.
/// ============================================================
ModuleRuntimeDescriptor createFarmManagementDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'farm_management',
    displayName: 'Farm Management',
    description: 'Manage farms, fields, crops, and livestock operations',
    iconKey: 'agriculture',
    route: '/farm',
    displayOrder: 1,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        moduleKey: 'farm_management',
        widgetKey: 'farm_kpis',
        displayName: 'Farm KPIs',
        sectionKey: 'farm',
        displayOrder: 1,
        width: 1,
        height: 1,
        iconKey: 'analytics',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'farm_management',
        widgetKey: 'farm_summary',
        displayName: 'Farm Summary',
        sectionKey: 'farm',
        displayOrder: 2,
        width: 2,
        height: 1,
        iconKey: 'agriculture',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'farm_management',
        widgetKey: 'farm_livestock',
        displayName: 'Livestock Overview',
        sectionKey: 'farm',
        displayOrder: 3,
        width: 1,
        height: 1,
        iconKey: 'pets',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'farm_management',
        widgetKey: 'farm_weather',
        displayName: 'Weather',
        sectionKey: 'farm',
        displayOrder: 4,
        width: 1,
        height: 1,
        iconKey: 'wb_sunny',
        refreshIntervalSeconds: 300,
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'farm_management',
        widgetKey: 'farm_activity_timeline',
        displayName: 'Activity Timeline',
        sectionKey: 'farm',
        displayOrder: 5,
        width: 2,
        height: 1,
        iconKey: 'timeline',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'farm_management',
        widgetKey: 'farm_production_summary',
        displayName: 'Production Summary',
        sectionKey: 'farm',
        displayOrder: 6,
        width: 2,
        height: 1,
        iconKey: 'production_quantity_limits',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'farm_management',
        widgetKey: 'farm_stock_summary',
        displayName: 'Stock Summary',
        sectionKey: 'farm',
        displayOrder: 7,
        width: 1,
        height: 1,
        iconKey: 'inventory',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'farm_management',
        widgetKey: 'farm_alerts',
        displayName: 'Farm Alerts',
        sectionKey: 'farm',
        displayOrder: 8,
        width: 2,
        height: 1,
        iconKey: 'warning',
        refreshIntervalSeconds: 60,
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'farm_management',
        widgetKey: 'farm_quick_actions',
        displayName: 'Quick Actions',
        sectionKey: 'farm',
        displayOrder: 9,
        width: 1,
        height: 1,
        iconKey: 'flash_on',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'farm_management',
        widgetKey: 'farm_farm_selector',
        displayName: 'Farm Selector',
        sectionKey: 'farm',
        displayOrder: 0,
        width: 2,
        height: 1,
        iconKey: 'swap_horiz',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'farm_home_summary_card',
        widgetType: 'card',
        displayName: 'Farm Summary',
        displayOrder: 1,
        iconKey: 'agriculture',
        priority: 10,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'farm_home_alerts',
        widgetType: 'alert',
        displayName: 'Farm Alerts',
        displayOrder: 2,
        iconKey: 'warning',
        priority: 8,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'farm_home_weather',
        widgetType: 'card',
        displayName: 'Weather Forecast',
        displayOrder: 3,
        iconKey: 'wb_sunny',
        priority: 6,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'farm_home_tips',
        widgetType: 'tip',
        displayName: 'Farming Tips',
        displayOrder: 4,
        iconKey: 'lightbulb',
        priority: 4,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'farm_add_farm',
        label: 'Add Farm',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/farm/create',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'farm_add_field',
        label: 'Add Field',
        iconKey: 'terrain',
        displayOrder: 2,
        route: '/farm/fields/create',
      ),
      QuickActionDescriptor(
        actionKey: 'farm_add_livestock',
        label: 'Add Livestock',
        iconKey: 'pets',
        displayOrder: 3,
        route: '/farm/livestock/create',
      ),
      QuickActionDescriptor(
        actionKey: 'farm_record_activity',
        label: 'Record Activity',
        iconKey: 'edit_note',
        displayOrder: 4,
        route: '/farm/activities',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'farm_notifications',
        displayName: 'Farm Management',
        notificationTypes: [
          'vaccination',
          'weather',
          'harvest',
          'task',
          'crop_stage',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'farm_search',
        displayName: 'Farm Management',
        entityTypes: ['farms', 'animals', 'fields', 'crops'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'farm_analytics',
        displayName: 'Farm Management',
        metricKeys: [
          'farm_count',
          'field_count',
          'livestock_count',
          'production_volume',
          'crop_yield',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/farm',
        name: 'farm_dashboard',
        isPrimary: true,
        displayOrder: 1,
      ),
      RouteDescriptor(
        path: '/farm/create',
        name: 'farm_create',
        displayOrder: 2,
      ),
      RouteDescriptor(
        path: '/farm/activities',
        name: 'farm_activities',
        displayOrder: 3,
      ),
      RouteDescriptor(
        path: '/farm/fields/create',
        name: 'farm_fields_create',
        displayOrder: 4,
      ),
      RouteDescriptor(
        path: '/farm/livestock/create',
        name: 'farm_livestock_create',
        displayOrder: 5,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'farm:view',
        displayName: 'View Farms',
        description: 'Ability to view farm information',
      ),
      PermissionDescriptor(
        permissionKey: 'farm:create',
        displayName: 'Create Farms',
        description: 'Ability to create new farms',
      ),
      PermissionDescriptor(
        permissionKey: 'farm:edit',
        displayName: 'Edit Farms',
        description: 'Ability to edit farm information',
      ),
      PermissionDescriptor(
        permissionKey: 'farm:delete',
        displayName: 'Delete Farms',
        description: 'Ability to delete farms',
      ),
      PermissionDescriptor(
        permissionKey: 'farm:manage_livestock',
        displayName: 'Manage Livestock',
        description: 'Ability to manage livestock records',
      ),
      PermissionDescriptor(
        permissionKey: 'farm:manage_fields',
        displayName: 'Manage Fields',
        description: 'Ability to manage field records',
      ),
    ],
  );
}
