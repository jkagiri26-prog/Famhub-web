/// ============================================================
/// FINANCING MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/module/ = module registration
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
/// FINANCING MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createFinancingDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'finance',
    displayName: 'Finance',
    description: 'Agricultural loans, credit, and financial services',
    iconKey: 'finance',
    route: '/finance',
    displayOrder: 4,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        moduleKey: 'finance',
        widgetKey: 'finance_wallet',
        displayName: 'Wallet Overview',
        sectionKey: 'finance',
        displayOrder: 1,
        width: 1,
        height: 1,
        iconKey: 'wallet',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'finance',
        widgetKey: 'finance_loans',
        displayName: 'Active Loans',
        sectionKey: 'finance',
        displayOrder: 2,
        width: 2,
        height: 1,
        iconKey: 'account_balance',
        refreshIntervalSeconds: 120,
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'finance',
        widgetKey: 'finance_transactions',
        displayName: 'Recent Transactions',
        sectionKey: 'finance',
        displayOrder: 3,
        width: 2,
        height: 1,
        iconKey: 'receipt_long',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'finance',
        widgetKey: 'finance_credit_health',
        displayName: 'Credit Health',
        sectionKey: 'finance',
        displayOrder: 4,
        width: 1,
        height: 1,
        iconKey: 'health_and_safety',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'finance',
        widgetKey: 'finance_loan_offers',
        displayName: 'Loan Offers',
        sectionKey: 'finance',
        displayOrder: 5,
        width: 1,
        height: 1,
        iconKey: 'local_offer',
        refreshIntervalSeconds: 300,
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'finance_home_balance',
        widgetType: 'card',
        displayName: 'Account Balance',
        displayOrder: 1,
        iconKey: 'account_balance_wallet',
        priority: 8,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'finance_home_payment_alert',
        widgetType: 'alert',
        displayName: 'Payment Due Alert',
        displayOrder: 2,
        iconKey: 'payment',
        priority: 9,
      ),
    ],

    // ── Quick Action Contributions ──
    //
    // Only actions that resolve to a registered route belong here. Loan
    // requests and payments are not implemented yet, so no affordance is
    // advertised for them.
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'finance_view_transactions',
        label: 'Transactions',
        iconKey: 'receipt_long',
        displayOrder: 3,
        route: '/finance',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'finance_notifications',
        displayName: 'Finance',
        notificationTypes: [
          'payment_due',
          'loan_approved',
          'loan_rejected',
          'wallet_credit',
          'wallet_debit',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'finance_search',
        displayName: 'Finance',
        entityTypes: ['transactions', 'wallet', 'loans'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'finance_analytics',
        displayName: 'Finance',
        metricKeys: [
          'total_balance',
          'active_loans',
          'loan_amount',
          'repayment_rate',
          'credit_score',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    //
    // Declarative catalogue only. The GoRouter instance is built by
    // DynamicRouteRegistrar from `system.modules` + ModulePageRegistry; the
    // registered finance paths are `/finance`, `/finance/catalogue`,
    // `/finance/management` and `/finance/providers/:slug`.
    routes: [
      RouteDescriptor(
        path: '/finance',
        name: 'finance',
        isPrimary: true,
        displayOrder: 1,
      ),
      RouteDescriptor(
        path: '/finance/catalogue',
        name: 'finance_catalogue',
        displayOrder: 4,
      ),
      RouteDescriptor(
        path: '/finance/management',
        name: 'finance_management',
        displayOrder: 5,
      ),
      RouteDescriptor(
        path: '/finance/providers/:slug',
        name: 'finance_provider_detail',
        displayOrder: 6,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'finance:view',
        displayName: 'View Finance',
        description: 'Ability to view financial information',
      ),
      PermissionDescriptor(
        permissionKey: 'finance:request_loan',
        displayName: 'Request Loans',
        description: 'Ability to request new loans',
      ),
      PermissionDescriptor(
        permissionKey: 'finance:make_payment',
        displayName: 'Make Payments',
        description: 'Ability to make loan payments',
      ),
    ],
  );
}
