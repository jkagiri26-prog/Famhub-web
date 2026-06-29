/// ============================================================
/// AGRIBUSINESS MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/agribusiness/module/ = module registration
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
/// AGRIBUSINESS MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createAgribusinessDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'agribusiness',
    displayName: 'Agribusiness',
    description: 'Business management tools for agricultural enterprises',
    iconKey: 'business',
    route: '/agribusiness',
    displayOrder: 9,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'agribusiness_pnl',
        displayName: 'Profit & Loss',
        sectionKey: 'business',
        displayOrder: 1,
        width: 2,
        height: 1,
        iconKey: 'account_balance',
        refreshIntervalSeconds: 3600,
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'agribusiness_inventory',
        displayName: 'Business Inventory',
        sectionKey: 'business',
        displayOrder: 2,
        width: 1,
        height: 1,
        iconKey: 'inventory',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'agribusiness_expenses',
        displayName: 'Expense Tracking',
        sectionKey: 'business',
        displayOrder: 3,
        width: 1,
        height: 1,
        iconKey: 'receipt_long',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'agribusiness_staff',
        displayName: 'Staff Overview',
        sectionKey: 'business',
        displayOrder: 4,
        width: 2,
        height: 1,
        iconKey: 'people',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'agribusiness_home_card',
        widgetType: 'card',
        displayName: 'Business Summary',
        displayOrder: 1,
        iconKey: 'business',
        priority: 7,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'agribusiness_home_tip',
        widgetType: 'tip',
        displayName: 'Business Tips',
        displayOrder: 2,
        iconKey: 'lightbulb',
        priority: 4,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'agribusiness_add_expense',
        label: 'Add Expense',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/agribusiness',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'agribusiness_invoice',
        label: 'Create Invoice',
        iconKey: 'receipt',
        displayOrder: 2,
        route: '/agribusiness',
      ),
      QuickActionDescriptor(
        actionKey: 'agribusiness_report',
        label: 'Business Report',
        iconKey: 'assessment',
        displayOrder: 3,
        route: '/agribusiness',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'agribusiness_notifications',
        displayName: 'Agribusiness',
        notificationTypes: [
          'expense_alert',
          'invoice_due',
          'inventory_low',
          'payroll_reminder',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'agribusiness_search',
        displayName: 'Agribusiness',
        entityTypes: ['invoices', 'expenses', 'inventory', 'staff'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'agribusiness_analytics',
        displayName: 'Agribusiness',
        metricKeys: [
          'revenue',
          'expenses',
          'profit_margin',
          'inventory_value',
          'staff_count',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/agribusiness',
        name: 'agribusiness',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'agribusiness:view',
        displayName: 'View Business',
        description: 'Ability to view business information',
      ),
      PermissionDescriptor(
        permissionKey: 'agribusiness:edit',
        displayName: 'Edit Business',
        description: 'Ability to edit business records',
      ),
      PermissionDescriptor(
        permissionKey: 'agribusiness:finance',
        displayName: 'Manage Finances',
        description: 'Ability to manage business finances',
      ),
    ],
  );
}
