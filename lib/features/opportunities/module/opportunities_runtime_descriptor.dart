/// ============================================================
/// OPPORTUNITIES MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/opportunities/module/ = module registration
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
/// OPPORTUNITIES MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createOpportunitiesDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'opportunities',
    displayName: 'Opportunities',
    description: 'Grants, tenders, and business opportunities',
    iconKey: 'opportunities',
    route: '/opportunities',
    displayOrder: 10,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'opportunities_active_grants',
        displayName: 'Active Grants',
        sectionKey: 'opportunities',
        displayOrder: 1,
        width: 1,
        height: 1,
        iconKey: 'volunteer_activism',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'opportunities_tenders',
        displayName: 'Open Tenders',
        sectionKey: 'opportunities',
        displayOrder: 2,
        width: 1,
        height: 1,
        iconKey: 'gavel',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'opportunities_recommended',
        displayName: 'Recommended',
        sectionKey: 'opportunities',
        displayOrder: 3,
        width: 2,
        height: 1,
        iconKey: 'recommend',
        refreshIntervalSeconds: 3600,
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'opportunities_deadlines',
        displayName: 'Upcoming Deadlines',
        sectionKey: 'opportunities',
        displayOrder: 4,
        width: 2,
        height: 1,
        iconKey: 'event',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'opportunities_home_card',
        widgetType: 'card',
        displayName: 'Opportunities',
        displayOrder: 1,
        iconKey: 'trending_up',
        priority: 6,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'opportunities_home_alert',
        widgetType: 'alert',
        displayName: 'Deadline Alert',
        displayOrder: 2,
        iconKey: 'alarm',
        priority: 8,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'opportunities_apply_grant',
        label: 'Apply for Grant',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/opportunities',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'opportunities_browse_tenders',
        label: 'Browse Tenders',
        iconKey: 'search',
        displayOrder: 2,
        route: '/opportunities',
      ),
      QuickActionDescriptor(
        actionKey: 'opportunities_track_status',
        label: 'Track Applications',
        iconKey: 'track_changes',
        displayOrder: 3,
        route: '/opportunities',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'opportunities_notifications',
        displayName: 'Opportunities',
        notificationTypes: [
          'new_grant',
          'new_tender',
          'deadline_reminder',
          'application_status',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'opportunities_search',
        displayName: 'Opportunities',
        entityTypes: ['grants', 'tenders', 'applications'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'opportunities_analytics',
        displayName: 'Opportunities',
        metricKeys: [
          'active_applications',
          'grants_awarded',
          'total_funding',
          'success_rate',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/opportunities',
        name: 'opportunities',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'opportunities:view',
        displayName: 'View Opportunities',
        description: 'Ability to view grants and tenders',
      ),
      PermissionDescriptor(
        permissionKey: 'opportunities:apply',
        displayName: 'Apply',
        description: 'Ability to apply for opportunities',
      ),
    ],
  );
}
