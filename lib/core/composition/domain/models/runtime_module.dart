import 'package:flutter/foundation.dart';

/// ============================================================
/// RUNTIME MODULE (COMPOSITION CORE)
/// ============================================================
///
/// Represents a fully resolved, governance-evaluated module
/// ready for rendering by the composition layer.
///
/// This is the FINAL output after:
///   1. Backend fetch (system.modules)
///   2. Dependency resolution
///   3. Context engine filtering
///   4. Feature flag / governance evaluation
///   5. Dashboard section assignment
///   6. Widget registration resolution
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/domain/models/ = composition domain
///
/// ✅ Responsibilities:
///   - Immutable runtime snapshot of a module after all filtering
///   - Carries resolved metadata for rendering (no lookups needed)
///   - Ready for direct consumption by UI components
///
/// ❌ Does NOT:
///   - Reference registries, services, or UI
///   - Perform any evaluations or lookups
///   - Contain business logic
/// ============================================================
@immutable
class RuntimeModule {
  /// Unique module identifier (from backend: module_key)
  final String moduleId;

  /// Human-readable display name
  final String displayName;

  /// Module description
  final String description;

  /// Entry route path for navigation
  final String route;

  /// Icon key for UI resolution
  final String iconKey;

  /// Display order for sorting
  final int displayOrder;

  // ── Visibility Flags (resolved) ──
  final bool sidebarVisible;
  final bool bottomNavVisible;
  final bool dashboardVisible;
  final bool quickActionVisible;
  final bool launcherVisible;

  // ── State Flags (resolved) ──
  final bool isEnabled;
  final bool maintenanceMode;
  final String? maintenanceMessage;

  // ── Grouping Metadata ──
  final String? section;
  final String? category;
  final String? group;
  final String? sortGroup;
  final String? parentModuleId;

  // ── Badge & Notifications ──
  final String? badgeText;
  final String? badgeColor;
  final String? notificationCountSource;

  // ── Pinning & Defaults ──
  final bool pinned;
  final bool defaultOpen;

  // ── Device Restrictions (resolved) ──
  final bool desktopOnly;
  final bool mobileOnly;
  final bool tabletOnly;

  // ── Governance (resolved) ──
  final bool premiumOnly;
  final bool requiresSubscription;
  final bool requiresEntity;
  final bool requiresFarm;
  final bool requiresBusiness;
  final bool requiresVerification;

  // ── Dashboard Metadata ──
  final String? dashboardSection;
  final int dashboardPriority;

  // ── Widget Registration ──
  final String? widgetBuilderKey;

  // ── Capabilities ──
  final bool supportsGuest;
  final bool supportsOffline;
  final bool supportsSync;
  final bool supportsSearch;
  final bool supportsNotifications;

  // ── Observability ──
  final String? denialReason;

  const RuntimeModule({
    required this.moduleId,
    required this.displayName,
    this.description = '',
    required this.route,
    this.iconKey = 'widgets',
    this.displayOrder = 999,

    // ── Visibility ──
    this.sidebarVisible = false,
    this.bottomNavVisible = false,
    this.dashboardVisible = false,
    this.quickActionVisible = false,
    this.launcherVisible = false,

    // ── State ──
    this.isEnabled = true,
    this.maintenanceMode = false,
    this.maintenanceMessage,

    // ── Grouping ──
    this.section,
    this.category,
    this.group,
    this.sortGroup,
    this.parentModuleId,

    // ── Badge ──
    this.badgeText,
    this.badgeColor,
    this.notificationCountSource,

    // ── Pinning ──
    this.pinned = false,
    this.defaultOpen = false,

    // ── Device ──
    this.desktopOnly = false,
    this.mobileOnly = false,
    this.tabletOnly = false,

    // ── Governance ──
    this.premiumOnly = false,
    this.requiresSubscription = false,
    this.requiresEntity = false,
    this.requiresFarm = false,
    this.requiresBusiness = false,
    this.requiresVerification = false,

    // ── Dashboard ──
    this.dashboardSection,
    this.dashboardPriority = 0,

    // ── Widget ──
    this.widgetBuilderKey,

    // ── Capabilities ──
    this.supportsGuest = false,
    this.supportsOffline = false,
    this.supportsSync = false,
    this.supportsSearch = false,
    this.supportsNotifications = false,

    // ── Observability ──
    this.denialReason,
  });

  /// Safe getter for navigation route
  String get navigationRoute => route;

  /// Whether this module is a child of another module
  bool get isChildModule =>
      parentModuleId != null && parentModuleId!.isNotEmpty;

  /// Whether this module has an active badge
  bool get hasBadge => badgeText != null || (badgeColor != null);

  /// Create a copy with updated fields
  RuntimeModule copyWith({
    String? moduleId,
    String? displayName,
    String? description,
    String? route,
    String? iconKey,
    int? displayOrder,
    bool? sidebarVisible,
    bool? bottomNavVisible,
    bool? dashboardVisible,
    bool? quickActionVisible,
    bool? launcherVisible,
    bool? isEnabled,
    bool? maintenanceMode,
    String? maintenanceMessage,
    String? section,
    String? category,
    String? group,
    String? sortGroup,
    String? parentModuleId,
    String? badgeText,
    String? badgeColor,
    String? notificationCountSource,
    bool? pinned,
    bool? defaultOpen,
    bool? desktopOnly,
    bool? mobileOnly,
    bool? tabletOnly,
    bool? premiumOnly,
    bool? requiresSubscription,
    bool? requiresEntity,
    bool? requiresFarm,
    bool? requiresBusiness,
    bool? requiresVerification,
    String? dashboardSection,
    int? dashboardPriority,
    String? widgetBuilderKey,
    bool? supportsGuest,
    bool? supportsOffline,
    bool? supportsSync,
    bool? supportsSearch,
    bool? supportsNotifications,
    String? denialReason,
  }) {
    return RuntimeModule(
      moduleId: moduleId ?? this.moduleId,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      route: route ?? this.route,
      iconKey: iconKey ?? this.iconKey,
      displayOrder: displayOrder ?? this.displayOrder,
      sidebarVisible: sidebarVisible ?? this.sidebarVisible,
      bottomNavVisible: bottomNavVisible ?? this.bottomNavVisible,
      dashboardVisible: dashboardVisible ?? this.dashboardVisible,
      quickActionVisible: quickActionVisible ?? this.quickActionVisible,
      launcherVisible: launcherVisible ?? this.launcherVisible,
      isEnabled: isEnabled ?? this.isEnabled,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      section: section ?? this.section,
      category: category ?? this.category,
      group: group ?? this.group,
      sortGroup: sortGroup ?? this.sortGroup,
      parentModuleId: parentModuleId ?? this.parentModuleId,
      badgeText: badgeText ?? this.badgeText,
      badgeColor: badgeColor ?? this.badgeColor,
      notificationCountSource:
          notificationCountSource ?? this.notificationCountSource,
      pinned: pinned ?? this.pinned,
      defaultOpen: defaultOpen ?? this.defaultOpen,
      desktopOnly: desktopOnly ?? this.desktopOnly,
      mobileOnly: mobileOnly ?? this.mobileOnly,
      tabletOnly: tabletOnly ?? this.tabletOnly,
      premiumOnly: premiumOnly ?? this.premiumOnly,
      requiresSubscription: requiresSubscription ?? this.requiresSubscription,
      requiresEntity: requiresEntity ?? this.requiresEntity,
      requiresFarm: requiresFarm ?? this.requiresFarm,
      requiresBusiness: requiresBusiness ?? this.requiresBusiness,
      requiresVerification: requiresVerification ?? this.requiresVerification,
      dashboardSection: dashboardSection ?? this.dashboardSection,
      dashboardPriority: dashboardPriority ?? this.dashboardPriority,
      widgetBuilderKey: widgetBuilderKey ?? this.widgetBuilderKey,
      supportsGuest: supportsGuest ?? this.supportsGuest,
      supportsOffline: supportsOffline ?? this.supportsOffline,
      supportsSync: supportsSync ?? this.supportsSync,
      supportsSearch: supportsSearch ?? this.supportsSearch,
      supportsNotifications:
          supportsNotifications ?? this.supportsNotifications,
      denialReason: denialReason ?? this.denialReason,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuntimeModule &&
          runtimeType == other.runtimeType &&
          moduleId == other.moduleId;

  @override
  int get hashCode => moduleId.hashCode;

  @override
  String toString() =>
      'RuntimeModule($moduleId: $displayName, enabled=$isEnabled)';
}
