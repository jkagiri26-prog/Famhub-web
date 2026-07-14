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
    moduleKey: 'financing',
    displayName: 'Financing',
    description: 'Agricultural loans, credit, and financial services',
    iconKey: 'finance',
    route: '/financing',
    displayOrder: 4,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        moduleKey: 'financing',
        widgetKey: 'finance_wallet',
        displayName: 'Wallet Overview',
        sectionKey: 'finance',
        displayOrder: 1,
        width: 1,
        height: 1,
        iconKey: 'wallet',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'financing',
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
        moduleKey: 'financing',
        widgetKey: 'finance_transactions',
        displayName: 'Recent Transactions',
        sectionKey: 'finance',
        displayOrder: 3,
        width: 2,
        height: 1,
        iconKey: 'receipt_long',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'financing',
        widgetKey: 'finance_credit_health',
        displayName: 'Credit Health',
        sectionKey: 'finance',
        displayOrder: 4,
        width: 1,
        height: 1,
        iconKey: 'health_and_safety',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'financing',
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
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'finance_request_loan',
        label: 'Request Loan',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/financing/loans/request',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'finance_make_payment',
        label: 'Make Payment',
        iconKey: 'payment',
        displayOrder: 2,
        route: '/financing/payment',
      ),
      QuickActionDescriptor(
        actionKey: 'finance_view_transactions',
        label: 'Transactions',
        iconKey: 'receipt_long',
        displayOrder: 3,
        route: '/financing',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'financing_notifications',
        displayName: 'Financing',
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
        providerKey: 'financing_search',
        displayName: 'Financing',
        entityTypes: ['transactions', 'wallet', 'loans'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'financing_analytics',
        displayName: 'Financing',
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
    routes: [
      RouteDescriptor(
        path: '/financing',
        name: 'financing',
        isPrimary: true,
        displayOrder: 1,
      ),
      RouteDescriptor(
        path: '/financing/loans/request',
        name: 'financing_loan_request',
        displayOrder: 2,
      ),
      RouteDescriptor(
        path: '/financing/payment',
        name: 'financing_payment',
        displayOrder: 3,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'financing:view',
        displayName: 'View Financing',
        description: 'Ability to view financial information',
      ),
      PermissionDescriptor(
        permissionKey: 'financing:request_loan',
        displayName: 'Request Loans',
        description: 'Ability to request new loans',
      ),
      PermissionDescriptor(
        permissionKey: 'financing:make_payment',
        displayName: 'Make Payments',
        description: 'Ability to make loan payments',
      ),
    ],
  );
}
