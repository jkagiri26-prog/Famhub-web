/// ============================================================
/// PROFILE MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/profile/module/ = module registration
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
/// PROFILE MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createProfileDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'profile',
    displayName: 'Profile',
    description: 'User profile and account management',
    iconKey: 'profile',
    route: '/profile',
    displayOrder: 15,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        moduleKey: 'profile',
        widgetKey: 'profile_overview',
        displayName: 'Profile Overview',
        sectionKey: 'profile',
        displayOrder: 1,
        width: 2,
        height: 1,
        iconKey: 'person',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'profile',
        widgetKey: 'profile_account_status',
        displayName: 'Account Status',
        sectionKey: 'profile',
        displayOrder: 2,
        width: 1,
        height: 1,
        iconKey: 'verified_user',
      ),
      DashboardWidgetDescriptor(
        moduleKey: 'profile',
        widgetKey: 'profile_activity',
        displayName: 'Recent Activity',
        sectionKey: 'profile',
        displayOrder: 3,
        width: 1,
        height: 1,
        iconKey: 'history',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'profile_home_greeting',
        widgetType: 'greeting',
        displayName: 'Good Morning!',
        displayOrder: 1,
        iconKey: 'waving_hand',
        priority: 100,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'profile_edit',
        label: 'Edit Profile',
        iconKey: 'edit',
        displayOrder: 1,
        route: '/profile',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'profile_settings',
        label: 'Account Settings',
        iconKey: 'settings',
        displayOrder: 2,
        route: '/profile',
      ),
      QuickActionDescriptor(
        actionKey: 'profile_security',
        label: 'Security',
        iconKey: 'security',
        displayOrder: 3,
        route: '/profile',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'profile_notifications',
        displayName: 'Profile',
        notificationTypes: ['profile_update', 'security_alert', 'login_alert'],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'profile_search',
        displayName: 'Profile',
        entityTypes: ['profile', 'settings', 'activity'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'profile_analytics',
        displayName: 'Profile',
        metricKeys: ['profile_completeness', 'login_count', 'account_age'],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/profile',
        name: 'profile',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'profile:view',
        displayName: 'View Profile',
        description: 'Ability to view own profile',
      ),
      PermissionDescriptor(
        permissionKey: 'profile:edit',
        displayName: 'Edit Profile',
        description: 'Ability to edit own profile',
      ),
    ],
  );
}
