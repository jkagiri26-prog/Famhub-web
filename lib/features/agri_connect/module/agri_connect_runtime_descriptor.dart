/// ============================================================
/// AGRICONNECT MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/agri_connect/module/ = module registration
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
/// AGRICONNECT MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createAgriConnectDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'agri_connect',
    displayName: 'AgriConnect',
    description: 'Farmer networking and community features',
    iconKey: 'community',
    route: '/connect',
    displayOrder: 12,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'connect_network',
        displayName: 'My Network',
        sectionKey: 'community',
        displayOrder: 1,
        width: 1,
        height: 1,
        iconKey: 'people',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'connect_discussions',
        displayName: 'Active Discussions',
        sectionKey: 'community',
        displayOrder: 2,
        width: 2,
        height: 1,
        iconKey: 'forum',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'connect_events',
        displayName: 'Community Events',
        sectionKey: 'community',
        displayOrder: 3,
        width: 1,
        height: 1,
        iconKey: 'event',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'connect_groups',
        displayName: 'Groups',
        sectionKey: 'community',
        displayOrder: 4,
        width: 2,
        height: 1,
        iconKey: 'groups',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'connect_home_card',
        widgetType: 'card',
        displayName: 'Community Updates',
        displayOrder: 1,
        iconKey: 'people',
        priority: 5,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'connect_home_news',
        widgetType: 'news',
        displayName: 'Community News',
        displayOrder: 2,
        iconKey: 'newspaper',
        priority: 4,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'connect_post',
        label: 'New Post',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/connect',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'connect_message',
        label: 'Send Message',
        iconKey: 'message',
        displayOrder: 2,
        route: '/connect',
      ),
      QuickActionDescriptor(
        actionKey: 'connect_find_farmers',
        label: 'Find Farmers',
        iconKey: 'person_search',
        displayOrder: 3,
        route: '/connect',
      ),
      QuickActionDescriptor(
        actionKey: 'connect_create_group',
        label: 'Create Group',
        iconKey: 'group_add',
        displayOrder: 4,
        route: '/connect',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'connect_notifications',
        displayName: 'AgriConnect',
        notificationTypes: [
          'new_message',
          'group_invite',
          'event_reminder',
          'post_reply',
          'connection_request',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'connect_search',
        displayName: 'AgriConnect',
        entityTypes: ['farmers', 'groups', 'posts', 'events'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'connect_analytics',
        displayName: 'AgriConnect',
        metricKeys: [
          'connections_count',
          'posts_count',
          'events_attended',
          'group_memberships',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/connect',
        name: 'agri_connect',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'connect:view',
        displayName: 'View Community',
        description: 'Ability to view community features',
      ),
      PermissionDescriptor(
        permissionKey: 'connect:post',
        displayName: 'Create Posts',
        description: 'Ability to create community posts',
      ),
      PermissionDescriptor(
        permissionKey: 'connect:message',
        displayName: 'Send Messages',
        description: 'Ability to send direct messages',
      ),
    ],
  );
}
