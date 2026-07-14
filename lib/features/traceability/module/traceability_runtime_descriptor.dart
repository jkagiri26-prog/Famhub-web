/// ============================================================
/// TRACEABILITY MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/traceability/module/ = module registration
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
/// TRACEABILITY MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createTraceabilityDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'traceability',
    displayName: 'Traceability',
    description: 'Farm-to-table product traceability and certification',
    iconKey: 'qr_code',
    route: '/traceability',
    displayOrder: 6,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        moduleKey: 'traceability',
        widgetKey: 'traceability_recent_scans',
        displayName: 'Recent Scans',
        sectionKey: 'traceability',
        displayOrder: 1,
        width: 1,
        height: 1,
        iconKey: 'qr_code_scanner',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'traceability',
        widgetKey: 'traceability_certifications',
        displayName: 'Certifications',
        sectionKey: 'traceability',
        displayOrder: 2,
        width: 1,
        height: 1,
        iconKey: 'verified',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'traceability',
        widgetKey: 'traceability_supply_chain',
        displayName: 'Supply Chain',
        sectionKey: 'traceability',
        displayOrder: 3,
        width: 2,
        height: 1,
        iconKey: 'share',
        refreshIntervalSeconds: 300,
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'traceability',
        widgetKey: 'traceability_alerts',
        displayName: 'Traceability Alerts',
        sectionKey: 'traceability',
        displayOrder: 4,
        width: 2,
        height: 1,
        iconKey: 'warning',
        refreshIntervalSeconds: 60,
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'traceability_home_card',
        widgetType: 'card',
        displayName: 'Traceability Status',
        displayOrder: 1,
        iconKey: 'qr_code',
        priority: 5,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'traceability_scan',
        label: 'Scan Product',
        iconKey: 'qr_code_scanner',
        displayOrder: 1,
        route: '/traceability',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'traceability_certify',
        label: 'Request Certification',
        iconKey: 'verified',
        displayOrder: 2,
        route: '/traceability',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'traceability_notifications',
        displayName: 'Traceability',
        notificationTypes: [
          'certification_approved',
          'certification_expiring',
          'batch_alert',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'traceability_search',
        displayName: 'Traceability',
        entityTypes: ['products', 'batches', 'certifications'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'traceability_analytics',
        displayName: 'Traceability',
        metricKeys: [
          'products_tracked',
          'certifications_active',
          'scan_count',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/traceability',
        name: 'traceability',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'traceability:view',
        displayName: 'View Traceability',
        description: 'Ability to view traceability data',
      ),
      PermissionDescriptor(
        permissionKey: 'traceability:scan',
        displayName: 'Scan Products',
        description: 'Ability to scan product QR codes',
      ),
      PermissionDescriptor(
        permissionKey: 'traceability:certify',
        displayName: 'Request Certifications',
        description: 'Ability to request product certifications',
      ),
    ],
  );
}
