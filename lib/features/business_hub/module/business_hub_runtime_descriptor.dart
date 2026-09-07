/// ============================================================
/// TRADER MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/business_hub/module/ = module registration
///
/// ✅ Responsibilities:
///   - Expose ModuleRuntimeDescriptor for the composition engine
///   - Define dashboard widgets, routes and permissions
///   - Pure descriptor — NO widget trees, NO rendering logic
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Backend (system.modules) is the ONLY source of truth
///   - Frontend module key is `trader` (feature folder: business_hub).
///     The Supabase schema identity `commerce` is NOT renamed — it is
///     the backend contract, never duplicated on the frontend.
/// ============================================================
library;

import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';

/// ============================================================
/// TRADER MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createBusinessHubDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'trader',
    displayName: 'Trader',
    description: 'Trading workspace for business entities and operations',
    iconKey: 'business',
    route: '/business-hub',
    displayOrder: 17,

    // ── Dashboard Widget Contributions ──
    // The workspace composes sections from the business's capabilities,
    // NOT from business type. More widgets are added as operational
    // sections bind to real commerce backend contracts.
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        moduleKey: 'trader',
        widgetKey: 'business_hub_operations',
        displayName: 'Business Operations',
        sectionKey: 'business_hub',
        displayOrder: 1,
        width: 2,
        height: 1,
        iconKey: 'business',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'business_hub_home_card',
        widgetType: 'card',
        displayName: 'Trader',
        displayOrder: 1,
        iconKey: 'business',
        priority: 6,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/business-hub',
        name: 'business_hub',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'business_hub:view',
        displayName: 'View Trader',
        description: 'Ability to view business entities and operations',
      ),
      PermissionDescriptor(
        permissionKey: 'business_hub:manage',
        displayName: 'Manage Businesses',
        description: 'Ability to manage business profiles and entities',
      ),
    ],
  );
}
