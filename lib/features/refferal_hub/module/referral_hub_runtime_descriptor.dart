/// ============================================================
/// REFERRAL HUB MODULE — RUNTIME DESCRIPTOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/refferal_hub/module/ = module registration
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
/// REFERRAL HUB MODULE DESCRIPTOR
/// ============================================================
ModuleRuntimeDescriptor createReferralHubDescriptor() {
  return const ModuleRuntimeDescriptor(
    moduleKey: 'referral_hub',
    displayName: 'Referral Hub',
    description: 'Referral program and reward tracking',
    iconKey: 'referral',
    route: '/referrals',
    displayOrder: 14,

    // ── Dashboard Widget Contributions ──
    dashboardWidgets: [
      DashboardWidgetDescriptor(
        widgetKey: 'referral_summary',
        displayName: 'Referral Summary',
        sectionKey: 'engagement',
        displayOrder: 1,
        width: 1,
        height: 1,
        iconKey: 'share',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'referral_rewards',
        displayName: 'Rewards Earned',
        sectionKey: 'engagement',
        displayOrder: 2,
        width: 1,
        height: 1,
        iconKey: 'card_giftcard',
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'referral_leaderboard',
        displayName: 'Leaderboard',
        sectionKey: 'engagement',
        displayOrder: 3,
        width: 2,
        height: 1,
        iconKey: 'leaderboard',
        refreshIntervalSeconds: 300,
      ),
      DashboardWidgetDescriptor(
        widgetKey: 'referral_invite',
        displayName: 'Invite Friends',
        sectionKey: 'engagement',
        displayOrder: 4,
        width: 2,
        height: 1,
        iconKey: 'person_add',
      ),
    ],

    // ── Home Screen Contributions ──
    homeWidgets: [
      HomeWidgetDescriptor(
        widgetKey: 'referral_home_card',
        widgetType: 'card',
        displayName: 'Referral Program',
        displayOrder: 1,
        iconKey: 'referral',
        priority: 4,
      ),
      HomeWidgetDescriptor(
        widgetKey: 'referral_home_promotion',
        widgetType: 'promotion',
        displayName: 'Referral Bonus',
        displayOrder: 2,
        iconKey: 'campaign',
        priority: 5,
      ),
    ],

    // ── Quick Action Contributions ──
    quickActions: [
      QuickActionDescriptor(
        actionKey: 'referral_invite',
        label: 'Invite Friend',
        iconKey: 'add_circle',
        displayOrder: 1,
        route: '/referrals',
        isPrimary: true,
      ),
      QuickActionDescriptor(
        actionKey: 'referral_view_rewards',
        label: 'View Rewards',
        iconKey: 'card_giftcard',
        displayOrder: 2,
        route: '/referrals',
      ),
      QuickActionDescriptor(
        actionKey: 'referral_share_code',
        label: 'Share Code',
        iconKey: 'share',
        displayOrder: 3,
        route: '/referrals',
      ),
    ],

    // ── Notification Providers ──
    notificationProviders: [
      NotificationProviderDescriptor(
        providerKey: 'referral_notifications',
        displayName: 'Referral Hub',
        notificationTypes: [
          'referral_signed_up',
          'reward_earned',
          'milestone_reached',
          'bonus_available',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Search Providers ──
    searchProviders: [
      SearchProviderDescriptor(
        providerKey: 'referral_search',
        displayName: 'Referral Hub',
        entityTypes: ['referrals', 'rewards', 'invites'],
        enabledByDefault: true,
      ),
    ],

    // ── Analytics Providers ──
    analyticsProviders: [
      AnalyticsProviderDescriptor(
        providerKey: 'referral_analytics',
        displayName: 'Referral Hub',
        metricKeys: [
          'referrals_count',
          'rewards_earned',
          'conversion_rate',
          'total_bonus',
        ],
        enabledByDefault: true,
      ),
    ],

    // ── Routes ──
    routes: [
      RouteDescriptor(
        path: '/referrals',
        name: 'referral_hub',
        isPrimary: true,
        displayOrder: 1,
      ),
    ],

    // ── Permissions ──
    permissions: [
      PermissionDescriptor(
        permissionKey: 'referral:view',
        displayName: 'View Referrals',
        description: 'Ability to view referral program',
      ),
      PermissionDescriptor(
        permissionKey: 'referral:invite',
        displayName: 'Invite Users',
        description: 'Ability to invite new users',
      ),
    ],
  );
}
