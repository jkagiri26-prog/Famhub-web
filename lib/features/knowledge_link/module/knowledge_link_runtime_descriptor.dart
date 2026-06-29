/// ============================================================
/// KNOWLEDGE LINK MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/knowledge_link/module/ = module registration
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
/// KNOWLEDGE LINK MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createKnowledgeLinkDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'knowledge_link',
    displayName: 'Knowledge Link',
    description: 'Agricultural knowledge base and learning resources',
    iconKey: 'library',
    route: '/knowledge',
    displayOrder: 8,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'knowledge_recommended',
        displayName: 'Recommended Content',
        sectionKey: 'knowledge',
        displayOrder: 1,
        width: 2,
        height: 1,
        iconKey: 'recommend',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'knowledge_recent_articles',
        displayName: 'Recent Articles',
        sectionKey: 'knowledge',
        displayOrder: 2,
        width: 1,
        height: 1,
        iconKey: 'article',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'knowledge_learning_progress',
        displayName: 'Learning Progress',
        sectionKey: 'knowledge',
        displayOrder: 3,
        width: 1,
        height: 1,
        iconKey: 'school',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'knowledge_tips',
        displayName: 'Daily Tips',
        sectionKey: 'knowledge',
        displayOrder: 4,
        width: 1,
        height: 1,
        iconKey: 'lightbulb',
        refreshIntervalSeconds: 3600,
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'knowledge_home_tip',
        widgetType: 'tip',
        displayName: 'Daily Farming Tip',
        displayOrder: 1,
        iconKey: 'lightbulb',
        priority: 6,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'knowledge_home_announcement',
        widgetType: 'announcement',
        displayName: 'Knowledge Announcements',
        displayOrder: 2,
        iconKey: 'campaign',
        priority: 4,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'knowledge_home_pinned_action',
        widgetType: 'pinned_action',
        displayName: 'Ask AI',
        displayOrder: 3,
        iconKey: 'smart_toy',
        priority: 7,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'knowledge_ask_ai',
        label: 'Ask AI',
        iconKey: 'smart_toy',
        displayOrder: 1,
        route: '/knowledge',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'knowledge_browse',
        label: 'Browse Knowledge Base',
        iconKey: 'library',
        displayOrder: 2,
        route: '/knowledge',
      ),
      QuickActionDescriptor(
        actionKey: 'knowledge_recent',
        label: 'Recent Articles',
        iconKey: 'history',
        displayOrder: 3,
        route: '/knowledge',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'knowledge_notifications',
        displayName: 'Knowledge Link',
        notificationTypes: [
          'new_content',
          'course_completion',
          'recommendation',
          'tip_of_day',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'knowledge_search',
        displayName: 'Knowledge Link',
        entityTypes: ['articles', 'courses', 'videos', 'guides'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'knowledge_analytics',
        displayName: 'Knowledge Link',
        metricKeys: [
          'articles_read',
          'courses_completed',
          'learning_hours',
          'quiz_scores',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/knowledge',
        name: 'knowledge',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'knowledge:view',
        displayName: 'View Knowledge',
        description: 'Ability to view knowledge base content',
      ),
      PermissionDescriptor(
        permissionKey: 'knowledge:ask_ai',
        displayName: 'Ask AI',
        description: 'Ability to use AI assistant',
      ),
      PermissionDescriptor(
        permissionKey: 'knowledge:download',
        displayName: 'Download Content',
        description: 'Ability to download educational content',
      ),
    ],
  );
}
