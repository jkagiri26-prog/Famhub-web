/// ============================================================
/// LOGISTICS MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/module/ = module registration
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
/// LOGISTICS MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createLogisticsDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'logistics',
    displayName: 'Logistics',
    description: 'Transportation and supply chain management',
    iconKey: 'shipping',
    route: '/logistics',
    displayOrder: 5,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'logistics_active_shipments',
        displayName: 'Active Shipments',
        sectionKey: 'logistics',
        displayOrder: 1,
        width: 2,
        height: 1,
        iconKey: 'local_shipping',
        refreshIntervalSeconds: 60,
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'logistics_transporters',
        displayName: 'Available Transporters',
        sectionKey: 'logistics',
        displayOrder: 2,
        width: 1,
        height: 1,
        iconKey: 'person_pin',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'logistics_delivery_status',
        displayName: 'Delivery Status',
        sectionKey: 'logistics',
        displayOrder: 3,
        width: 1,
        height: 1,
        iconKey: 'check_circle',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'logistics_route_planning',
        displayName: 'Route Planning',
        sectionKey: 'logistics',
        displayOrder: 4,
        width: 2,
        height: 1,
        iconKey: 'route',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'logistics_home_card',
        widgetType: 'card',
        displayName: 'Logistics Summary',
        displayOrder: 1,
        iconKey: 'local_shipping',
        priority: 6,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'logistics_home_alert',
        widgetType: 'alert',
        displayName: 'Delivery Alerts',
        displayOrder: 2,
        iconKey: 'notifications_active',
        priority: 7,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'logistics_book_transport',
        label: 'Book Transport',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/logistics',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'logistics_track_shipment',
        label: 'Track Shipment',
        iconKey: 'pin_drop',
        displayOrder: 2,
        route: '/logistics',
      ),
      QuickActionDescriptor(
        actionKey: 'logistics_find_transporter',
        label: 'Find Transporter',
        iconKey: 'person_search',
        displayOrder: 3,
        route: '/logistics',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'logistics_notifications',
        displayName: 'Logistics',
        notificationTypes: [
          'shipment_pickup',
          'shipment_delivered',
          'shipment_delayed',
          'transporter_assigned',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'logistics_search',
        displayName: 'Logistics',
        entityTypes: ['shipments', 'transporters', 'routes'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'logistics_analytics',
        displayName: 'Logistics',
        metricKeys: [
          'active_shipments',
          'delivery_rate',
          'avg_delivery_time',
          'transporter_count',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/logistics',
        name: 'logistics',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'logistics:view',
        displayName: 'View Logistics',
        description: 'Ability to view logistics information',
      ),
      PermissionDescriptor(
        permissionKey: 'logistics:book',
        displayName: 'Book Transport',
        description: 'Ability to book transportation',
      ),
      PermissionDescriptor(
        permissionKey: 'logistics:track',
        displayName: 'Track Shipments',
        description: 'Ability to track shipments',
      ),
    ],
  );
}
