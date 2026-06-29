/// ============================================================
/// CARBON CREDIT MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/carbon_credit/module/ = module registration
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
/// CARBON CREDIT MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createCarbonCreditDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'carbon_credit',
    displayName: 'Carbon Credit',
    description: 'Carbon sequestration tracking and credit trading',
    iconKey: 'eco',
    route: '/carbon-credit',
    displayOrder: 7,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'carbon_footprint',
        displayName: 'Carbon Footprint',
        sectionKey: 'sustainability',
        displayOrder: 1,
        width: 1,
        height: 1,
        iconKey: 'footprint',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'carbon_credits_earned',
        displayName: 'Credits Earned',
        sectionKey: 'sustainability',
        displayOrder: 2,
        width: 1,
        height: 1,
        iconKey: 'emoji_events',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'carbon_trading',
        displayName: 'Credit Trading',
        sectionKey: 'sustainability',
        displayOrder: 3,
        width: 2,
        height: 1,
        iconKey: 'swap_horiz',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'carbon_sequestration',
        displayName: 'Sequestration',
        sectionKey: 'sustainability',
        displayOrder: 4,
        width: 2,
        height: 1,
        iconKey: 'forest',
        refreshIntervalSeconds: 3600,
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'carbon_home_card',
        widgetType: 'card',
        displayName: 'Sustainability Score',
        displayOrder: 1,
        iconKey: 'eco',
        priority: 5,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'carbon_home_promotion',
        widgetType: 'promotion',
        displayName: 'Green Incentives',
        displayOrder: 2,
        iconKey: 'campaign',
        priority: 3,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'carbon_measure',
        label: 'Measure Footprint',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/carbon-credit',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'carbon_trade',
        label: 'Trade Credits',
        iconKey: 'swap_horiz',
        displayOrder: 2,
        route: '/carbon-credit',
      ),
      QuickActionDescriptor(
        actionKey: 'carbon_certify',
        label: 'Request Certification',
        iconKey: 'verified',
        displayOrder: 3,
        route: '/carbon-credit',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'carbon_notifications',
        displayName: 'Carbon Credit',
        notificationTypes: [
          'credit_milestone',
          'certification_ready',
          'trade_match',
          'price_alert',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'carbon_search',
        displayName: 'Carbon Credit',
        entityTypes: ['credits', 'certifications', 'projects'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'carbon_analytics',
        displayName: 'Carbon Credit',
        metricKeys: [
          'total_credits',
          'footprint_reduction',
          'trades_completed',
          'certification_status',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/carbon-credit',
        name: 'carbon_credit',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'carbon:view',
        displayName: 'View Carbon',
        description: 'Ability to view carbon credit data',
      ),
      PermissionDescriptor(
        permissionKey: 'carbon:measure',
        displayName: 'Measure Footprint',
        description: 'Ability to measure carbon footprint',
      ),
      PermissionDescriptor(
        permissionKey: 'carbon:trade',
        displayName: 'Trade Credits',
        description: 'Ability to trade carbon credits',
      ),
    ],
  );
}
