/// ============================================================
/// ADMIN CONSOLE MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/module/ = module registration
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
/// ADMIN CONSOLE MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createAdminConsoleDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'admin_console',
    displayName: 'Admin Console',
    description: 'System administration and configuration',
    iconKey: 'admin',
    route: '/admin',
    displayOrder: 16,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'admin_system_health',
        displayName: 'System Health',
        sectionKey: 'administration',
        displayOrder: 1,
        width: 2,
        height: 1,
        iconKey: 'monitor_heart',
        refreshIntervalSeconds: 30,
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'admin_user_management',
        displayName: 'User Management',
        sectionKey: 'administration',
        displayOrder: 2,
        width: 2,
        height: 1,
        iconKey: 'people',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'admin_audit_log',
        displayName: 'Audit Log',
        sectionKey: 'administration',
        displayOrder: 3,
        width: 2,
        height: 1,
        iconKey: 'receipt_long',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'admin_module_control',
        displayName: 'Module Control',
        sectionKey: 'administration',
        displayOrder: 4,
        width: 2,
        height: 1,
        iconKey: 'tune',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'admin_metrics',
        displayName: 'System Metrics',
        sectionKey: 'administration',
        displayOrder: 5,
        width: 2,
        height: 1,
        iconKey: 'analytics',
        refreshIntervalSeconds: 30,
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'admin_configuration',
        displayName: 'Configuration',
        sectionKey: 'administration',
        displayOrder: 6,
        width: 2,
        height: 1,
        iconKey: 'settings',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'admin_home_card',
        widgetType: 'card',
        displayName: 'System Status',
        displayOrder: 1,
        iconKey: 'admin_panel_settings',
        priority: 10,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'admin_home_alert',
        widgetType: 'alert',
        displayName: 'System Alerts',
        displayOrder: 2,
        iconKey: 'warning',
        priority: 10,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'admin_system_status',
        label: 'System Status',
        iconKey: 'monitor',
        displayOrder: 1,
        route: '/admin',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'admin_users',
        label: 'Manage Users',
        iconKey: 'people',
        displayOrder: 2,
        route: '/admin',
      ),
      QuickActionDescriptor(
        actionKey: 'admin_logs',
        label: 'View Logs',
        iconKey: 'receipt_long',
        displayOrder: 3,
        route: '/admin',
      ),
      QuickActionDescriptor(
        actionKey: 'admin_modules',
        label: 'Module Control',
        iconKey: 'tune',
        displayOrder: 4,
        route: '/admin',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'admin_notifications',
        displayName: 'Admin Console',
        notificationTypes: [
          'system_alert',
          'user_report',
          'module_failure',
          'security_alert',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'admin_search',
        displayName: 'Admin Console',
        entityTypes: ['users', 'logs', 'modules', 'config'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'admin_analytics',
        displayName: 'Admin Console',
        metricKeys: [
          'active_users',
          'system_uptime',
          'error_rate',
          'module_count',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/admin',
        name: 'admin_console',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'admin:view',
        displayName: 'View Admin',
        description: 'Ability to view admin console',
        isSystem: true,
      ),
      PermissionDescriptor(
        permissionKey: 'admin:manage_users',
        displayName: 'Manage Users',
        description: 'Ability to manage user accounts',
        isSystem: true,
      ),
      PermissionDescriptor(
        permissionKey: 'admin:manage_modules',
        displayName: 'Manage Modules',
        description: 'Ability to manage system modules',
        isSystem: true,
      ),
      PermissionDescriptor(
        permissionKey: 'admin:view_logs',
        displayName: 'View Logs',
        description: 'Ability to view audit logs',
        isSystem: true,
      ),
      PermissionDescriptor(
        permissionKey: 'admin:configuration',
        displayName: 'Configuration',
        description: 'Ability to modify system configuration',
        isSystem: true,
      ),
    ],
  );
}
