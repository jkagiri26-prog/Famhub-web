class SystemModule {
  // ── Identity ──
  final String moduleKey;
  final String displayName;

  // ── Core state ──
  final bool isEnabled;
  final bool maintenanceMode;
  final String? maintenanceMessage;

  // ── Visibility flags ──
  final bool dashboardVisible;
  final bool sidebarVisible;
  final bool bottomNavVisible;
  final bool quickActionVisible;
  final bool launcherVisible;

  // ── Device restrictions ──
  final bool desktopOnly;
  final bool mobileOnly;
  final bool tabletOnly;

  // ── Governance ──
  final bool premiumOnly;
  final bool requiresSubscription;
  final bool requiresEntity;
  final bool requiresFarm;
  final bool requiresBusiness;
  final bool requiresVerification;

  // ── Display metadata ──
  final int displayOrder;
  final String? badgeText;
  final String? badgeColor;
  final String? notificationCountSource;
  final String? iconColor;
  final String? section;
  final String? category;
  final String? group;
  final String? parentModule;
  final String? sortGroup;
  final bool defaultOpen;
  final bool pinned;

  const SystemModule({
    // ── Required ──
    required this.moduleKey,
    required this.displayName,
    required this.isEnabled,

    // ── Core state (defaults) ──
    this.maintenanceMode = false,
    this.maintenanceMessage,

    // ── Visibility (defaults) ──
    this.dashboardVisible = false,
    this.sidebarVisible = false,
    this.bottomNavVisible = false,
    this.quickActionVisible = false,
    this.launcherVisible = false,

    // ── Device (no restrictions) ──
    this.desktopOnly = false,
    this.mobileOnly = false,
    this.tabletOnly = false,

    // ── Governance (defaults) ──
    this.premiumOnly = false,
    this.requiresSubscription = false,
    this.requiresEntity = false,
    this.requiresFarm = false,
    this.requiresBusiness = false,
    this.requiresVerification = false,

    // ── Display (defaults) ──
    this.displayOrder = 999,
    this.badgeText,
    this.badgeColor,
    this.notificationCountSource,
    this.iconColor,
    this.section,
    this.category,
    this.group,
    this.parentModule,
    this.sortGroup,
    this.defaultOpen = false,
    this.pinned = false,
  });

  factory SystemModule.fromMap(Map<String, dynamic> map) {
    return SystemModule(
      moduleKey: map['module_key']?.toString() ?? '',
      displayName: map['module_name']?.toString() ?? map['display_name']?.toString() ?? 'Unknown',
      isEnabled: map['is_enabled'] ?? false,
      maintenanceMode: map['maintenance_mode'] ?? false,
      maintenanceMessage: map['maintenance_message']?.toString(),
      dashboardVisible: map['dashboard_visible'] ?? false,
      sidebarVisible: map['sidebar_visible'] ?? false,
      bottomNavVisible: map['bottom_nav_visible'] ?? false,
      quickActionVisible: map['quick_action_visible'] ?? false,
      launcherVisible: map['launcher_visible'] ?? false,
      desktopOnly: map['desktop_only'] ?? false,
      mobileOnly: map['mobile_only'] ?? false,
      tabletOnly: map['tablet_only'] ?? false,
      premiumOnly: map['premium_only'] ?? false,
      requiresSubscription: map['requires_subscription'] ?? false,
      requiresEntity: map['requires_entity'] ?? false,
      requiresFarm: map['requires_farm'] ?? false,
      requiresBusiness: map['requires_business'] ?? false,
      requiresVerification: map['requires_verification'] ?? false,
      displayOrder: map['display_order'] ?? 999,
      badgeText: map['badge_text']?.toString(),
      badgeColor: map['badge_color']?.toString(),
      notificationCountSource: map['notification_count_source']?.toString(),
      iconColor: map['icon_color']?.toString(),
      section: map['section']?.toString(),
      category: map['category']?.toString(),
      group: map['group']?.toString(),
      parentModule: map['parent_module']?.toString(),
      sortGroup: map['sort_group']?.toString(),
      defaultOpen: map['default_open'] ?? false,
      pinned: map['pinned'] ?? false,
    );
  }
}
