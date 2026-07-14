import 'package:flutter/material.dart';

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/domain/models/composition_metrics.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

/// ============================================================
/// COMPOSITION NAVIGATION ITEM (OUTPUT MODEL)
/// ============================================================
///
/// A fully resolved navigation item from the composition engine.
/// Ready for direct consumption by sidebar/bottom nav/dashboard UI.
///
/// This is the composition-layer equivalent of NavItem,
/// produced directly from RuntimeModule data.
/// ============================================================
class CompositionNavItem {
  final String moduleKey;
  final String displayName;
  final String route;
  final IconData icon;
  final int displayOrder;

  // ── Visibility ──
  final bool sidebarVisible;
  final bool bottomNavVisible;
  final bool dashboardVisible;
  final bool quickActionVisible;
  final bool launcherVisible;

  // ── State ──
  final bool isEnabled;
  final bool maintenanceMode;
  final String? maintenanceMessage;

  // ── Sorting & grouping ──
  final String? section;
  final String? category;
  final String? group;
  final String? sortGroup;

  // ── Badge & notification ──
  final String? badgeText;
  final Color? badgeColor;
  final String? notificationCountSource;
  final int unreadCount;

  // ── Favorites & Pins ──
  final bool pinned;
  final bool defaultOpen;

  // ── Parent/child ──
  final String? parentModule;

  // ── Device restrictions ──
  final bool desktopOnly;
  final bool mobileOnly;
  final bool tabletOnly;

  const CompositionNavItem({
    required this.moduleKey,
    required this.displayName,
    required this.route,
    required this.icon,
    required this.displayOrder,
    this.sidebarVisible = true,
    this.bottomNavVisible = false,
    this.dashboardVisible = true,
    this.quickActionVisible = false,
    this.launcherVisible = false,
    this.isEnabled = true,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.section,
    this.category,
    this.group,
    this.sortGroup,
    this.badgeText,
    this.badgeColor,
    this.notificationCountSource,
    this.unreadCount = 0,
    this.pinned = false,
    this.defaultOpen = false,
    this.parentModule,
    this.desktopOnly = false,
    this.mobileOnly = false,
    this.tabletOnly = false,
  });

  /// Whether this item is visible on the given device
  /// Treats 'compactXs' as 'mobile' and 'ultraWide' as 'desktop'.
  bool isVisibleOnDevice(String deviceType) {
    final normalized = _normalizeDeviceType(deviceType);
    if (desktopOnly && normalized != 'desktop') return false;
    if (mobileOnly && normalized != 'mobile') return false;
    if (tabletOnly && normalized != 'tablet') return false;
    return true;
  }

  static String _normalizeDeviceType(String deviceType) {
    switch (deviceType) {
      case 'compactXs':
        return 'mobile';
      case 'ultraWide':
        return 'desktop';
      default:
        return deviceType;
    }
  }

  /// Whether this item has an active badge
  bool get hasBadge => badgeText != null || unreadCount > 0;

  /// Whether this item is a child module
  bool get isChildModule => parentModule != null && parentModule!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompositionNavItem &&
          runtimeType == other.runtimeType &&
          moduleKey == other.moduleKey;

  @override
  int get hashCode => moduleKey.hashCode;
}

/// ============================================================
/// COMPOSITION NAVIGATION BUILDER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/navigation/ = composition navigation layer
///
/// ✅ Responsibilities:
///   - Build CompositionNavItem from RuntimeModule
///   - Generate sidebar, bottom nav, dashboard, quick action lists
///   - Central place for all navigation UI data preparation
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Everything uses the same runtime data
///   - NO hardcoded module references
///   - NO if/else on role or module name
///   - All data originates from RuntimeModule (backend-driven)
///
/// 🧠 USAGE:
///   - Desktop Sidebar → generated from runtime registry
///   - Tablet Sidebar → generated from runtime registry
///   - Bottom Navigation → generated from runtime registry
///   - Quick Actions → generated from runtime registry
///   - Pinned Modules → generated from runtime registry
///   - Favorites → generated from runtime registry
/// ============================================================
class CompositionNavBuilder {
  /// ============================================================
  /// BUILD SINGLE NAV ITEM
  /// ============================================================
  static CompositionNavItem buildNavItem(
    RuntimeModule module, {
    int unreadCount = 0,
  }) {
    final iconData = IconResolver.resolve(module.iconKey);

    final Color? resolvedBadgeColor;
    if (module.badgeColor != null) {
      resolvedBadgeColor = _resolveColor(module.badgeColor!);
    } else {
      resolvedBadgeColor = null;
    }

    return CompositionNavItem(
      moduleKey: module.moduleId,
      displayName: module.displayName,
      route: module.route,
      icon: iconData,
      displayOrder: module.displayOrder,
      sidebarVisible: module.sidebarVisible,
      bottomNavVisible: module.bottomNavVisible,
      dashboardVisible: module.dashboardVisible,
      quickActionVisible: module.quickActionVisible,
      launcherVisible: module.launcherVisible,
      isEnabled: module.isEnabled,
      maintenanceMode: module.maintenanceMode,
      maintenanceMessage: module.maintenanceMessage,
      section: module.section,
      category: module.category,
      group: module.group,
      sortGroup: module.sortGroup,
      badgeText: module.badgeText,
      badgeColor: resolvedBadgeColor,
      notificationCountSource: module.notificationCountSource,
      unreadCount: unreadCount,
      pinned: module.pinned,
      defaultOpen: module.defaultOpen,
      parentModule: module.parentModuleId,
      desktopOnly: module.desktopOnly,
      mobileOnly: module.mobileOnly,
      tabletOnly: module.tabletOnly,
    );
  }

  /// ============================================================
  /// BUILD BATCH NAV ITEMS
  /// ============================================================
  static List<CompositionNavItem> buildNavItems(
    List<RuntimeModule> modules,
  ) {
    return modules
        .where((m) => m.isEnabled && !m.maintenanceMode)
        .map((m) => buildNavItem(m))
        .toList()
      ..sort((a, b) {
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;
        return a.displayOrder.compareTo(b.displayOrder);
      });
  }

  /// ============================================================
  /// GET SIDEBAR ITEMS
  /// ============================================================
  static List<CompositionNavItem> getSidebarItems(
    List<RuntimeModule> modules,
  ) {
    return modules
        .where((m) =>
            m.isEnabled && !m.maintenanceMode && m.sidebarVisible)
        .map((m) => buildNavItem(m))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// ============================================================
  /// GET BOTTOM NAV ITEMS
  /// ============================================================
  static List<CompositionNavItem> getBottomNavItems(
    List<RuntimeModule> modules,
  ) {
    return modules
        .where((m) =>
            m.isEnabled && !m.maintenanceMode && m.bottomNavVisible)
        .map((m) => buildNavItem(m))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// ============================================================
  /// GET DASHBOARD ITEMS
  /// ============================================================
  static List<CompositionNavItem> getDashboardItems(
    List<RuntimeModule> modules,
  ) {
    return modules
        .where((m) =>
            m.isEnabled && !m.maintenanceMode && m.dashboardVisible)
        .map((m) => buildNavItem(m))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// ============================================================
  /// GET QUICK ACTION ITEMS
  /// ============================================================
  static List<CompositionNavItem> getQuickActionItems(
    List<RuntimeModule> modules,
  ) {
    return modules
        .where((m) =>
            m.isEnabled && !m.maintenanceMode && m.quickActionVisible)
        .map((m) => buildNavItem(m))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// ============================================================
  /// GET PINNED ITEMS
  /// ============================================================
  static List<CompositionNavItem> getPinnedItems(
    List<RuntimeModule> modules,
  ) {
    return modules
        .where((m) => m.isEnabled && !m.maintenanceMode && m.pinned)
        .map((m) => buildNavItem(m))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// ============================================================
  /// RESOLVE COLOR STRING
  /// ============================================================
  static Color? _resolveColor(String colorString) {
    switch (colorString.toLowerCase()) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'amber':
        return Colors.amber;
      case 'green':
        return Colors.green;
      case 'blue':
        return Colors.blue;
      case 'purple':
        return Colors.purple;
      case 'pink':
        return Colors.pink;
      case 'grey':
      case 'gray':
        return Colors.grey;
      default:
        return null;
    }
  }
}
