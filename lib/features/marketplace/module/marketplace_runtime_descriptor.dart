/// ============================================================
/// MARKETPLACE MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/marketplace/module/ = module registration
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
/// MARKETPLACE MODULE DESCRIPTOR
/// ============================================================
///
/// Registers all marketplace contributions for the runtime engine.
/// ============================================================
ModuleRuntimeDescriptor createMarketplaceDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'marketplace',
    displayName: 'Marketplace',
    description: 'Buy and sell agricultural products and services',
    iconKey: 'store',
    route: '/marketplace',
    displayOrder: 2,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'marketplace_kpi_card',
        displayName: 'Marketplace KPI',
        sectionKey: 'marketplace',
        displayOrder: 1,
        width: 1,
        height: 1,
        iconKey: 'analytics',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'marketplace_featured_listings',
        displayName: 'Featured Listings',
        sectionKey: 'marketplace',
        displayOrder: 2,
        width: 2,
        height: 1,
        iconKey: 'store',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'marketplace_quick_sell',
        displayName: 'Quick Sell',
        sectionKey: 'marketplace',
        displayOrder: 3,
        width: 1,
        height: 1,
        iconKey: 'sell',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'marketplace_sales_metrics',
        displayName: 'Sales Metrics',
        sectionKey: 'marketplace',
        displayOrder: 4,
        width: 2,
        height: 1,
        iconKey: 'trending_up',
        refreshIntervalSeconds: 60,
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'marketplace_listing_performance',
        displayName: 'Listing Performance',
        sectionKey: 'marketplace',
        displayOrder: 5,
        width: 2,
        height: 1,
        iconKey: 'leaderboard',
        refreshIntervalSeconds: 120,
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'marketplace_home_promotions',
        widgetType: 'promotion',
        displayName: 'Marketplace Promotions',
        displayOrder: 1,
        iconKey: 'campaign',
        priority: 5,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'marketplace_home_tips',
        widgetType: 'tip',
        displayName: 'Selling Tips',
        displayOrder: 2,
        iconKey: 'lightbulb',
        priority: 3,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'marketplace_home_alerts',
        widgetType: 'alert',
        displayName: 'Market Alerts',
        displayOrder: 3,
        iconKey: 'notifications',
        priority: 4,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'marketplace_sell_product',
        label: 'Sell Product',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/marketplace/create',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'marketplace_browse',
        label: 'Browse Marketplace',
        iconKey: 'store',
        displayOrder: 2,
        route: '/marketplace',
      ),
      QuickActionDescriptor(
        actionKey: 'marketplace_my_listings',
        label: 'My Listings',
        iconKey: 'list_alt',
        displayOrder: 3,
        route: '/marketplace',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'marketplace_notifications',
        displayName: 'Marketplace',
        notificationTypes: ['new_listing', 'order', 'payment', 'message'],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'marketplace_search',
        displayName: 'Marketplace',
        entityTypes: ['listings', 'businesses', 'products'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'marketplace_analytics',
        displayName: 'Marketplace',
        metricKeys: [
          'listings_count',
          'sales_volume',
          'avg_price',
          'active_sellers',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/marketplace',
        name: 'marketplace',
        isPrimary: true,
        displayOrder: 1,
      ),
      RouteDescriptor(
        path: '/marketplace/create',
        name: 'marketplace_create',
        displayOrder: 2,
      ),
      RouteDescriptor(
        path: '/marketplace/:id',
        name: 'marketplace_detail',
        displayOrder: 3,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'marketplace:view',
        displayName: 'View Marketplace',
        description: 'Ability to view marketplace listings',
      ),
      PermissionDescriptor(
        permissionKey: 'marketplace:create',
        displayName: 'Create Listings',
        description: 'Ability to create new listings',
      ),
      PermissionDescriptor(
        permissionKey: 'marketplace:edit',
        displayName: 'Edit Listings',
        description: 'Ability to edit own listings',
      ),
      PermissionDescriptor(
        permissionKey: 'marketplace:delete',
        displayName: 'Delete Listings',
        description: 'Ability to delete own listings',
      ),
    ],
  );
}
