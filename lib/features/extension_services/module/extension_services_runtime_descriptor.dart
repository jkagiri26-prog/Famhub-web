/// ============================================================
/// EXTENSION SERVICES MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/extension_services/module/ = module registration
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
/// EXTENSION SERVICES MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createExtensionServicesDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'extension_services',
    displayName: 'Extension Services',
    description: 'Agricultural extension and advisory services',
    iconKey: 'support',
    route: '/extension',
    displayOrder: 11,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'extension_advisory',
        displayName: 'Advisory Services',
        sectionKey: 'extension',
        displayOrder: 1,
        width: 1,
        height: 1,
        iconKey: 'support_agent',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'extension_field_visits',
        displayName: 'Field Visits',
        sectionKey: 'extension',
        displayOrder: 2,
        width: 1,
        height: 1,
        iconKey: 'explore',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'extension_requests',
        displayName: 'Service Requests',
        sectionKey: 'extension',
        displayOrder: 3,
        width: 2,
        height: 1,
        iconKey: 'assignment',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'extension_training',
        displayName: 'Training Programs',
        sectionKey: 'extension',
        displayOrder: 4,
        width: 1,
        height: 1,
        iconKey: 'school',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'extension_home_card',
        widgetType: 'card',
        displayName: 'Extension Services',
        displayOrder: 1,
        iconKey: 'support',
        priority: 5,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'extension_home_news',
        widgetType: 'news',
        displayName: 'Extension News',
        displayOrder: 2,
        iconKey: 'newspaper',
        priority: 3,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'extension_request_service',
        label: 'Request Service',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/extension',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'extension_find_agent',
        label: 'Find Agent',
        iconKey: 'person_search',
        displayOrder: 2,
        route: '/extension',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'extension_notifications',
        displayName: 'Extension Services',
        notificationTypes: [
          'visit_scheduled',
          'service_update',
          'training_available',
          'agent_message',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'extension_search',
        displayName: 'Extension Services',
        entityTypes: ['agents', 'services', 'training_programs'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'extension_analytics',
        displayName: 'Extension Services',
        metricKeys: [
          'active_requests',
          'visits_completed',
          'trainings_attended',
          'satisfaction_rate',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/extension',
        name: 'extension',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'extension:view',
        displayName: 'View Extension',
        description: 'Ability to view extension services',
      ),
      PermissionDescriptor(
        permissionKey: 'extension:request',
        displayName: 'Request Services',
        description: 'Ability to request advisory services',
      ),
    ],
  );
}
