import 'package:flutter/material.dart';

/// ============================================================
/// NAVIGATION ITEM MODEL (ENTERPRISE GOVERNANCE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Pure data model for a navigation item
///   - Maps backend SystemModule fields to navigation
///   - Supports badges, pinned items, grouped navigation
///
/// ❌ Does NOT:
///   - Reference registries or services
///   - Contain business logic
///   - Import providers
/// ============================================================
class NavItem {
  // ── Identity ──
  final String moduleKey;
  final String displayName;
  final String route;
  final IconData icon;

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
  final int displayOrder;
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

  // ── Parent/child relationship ──
  final String? parentModule;

  // ── Device restrictions ──
  final bool desktopOnly;
  final bool mobileOnly;
  final bool tabletOnly;

  const NavItem({
    // ── Required ──
    required this.moduleKey,
    required this.displayName,
    required this.route,
    required this.icon,
    required this.displayOrder,

    // ── Visibility (defaults) ──
    this.sidebarVisible = true,
    this.bottomNavVisible = false,
    this.dashboardVisible = true,
    this.quickActionVisible = false,
    this.launcherVisible = false,

    // ── State (defaults) ──
    this.isEnabled = true,
    this.maintenanceMode = false,
    this.maintenanceMessage,

    // ── Sorting & grouping (defaults) ──
    this.section,
    this.category,
    this.group,
    this.sortGroup,

    // ── Badge & notifications (defaults) ──
    this.badgeText,
    this.badgeColor,
    this.notificationCountSource,
    this.unreadCount = 0,

    // ── Pins & favorites (defaults) ──
    this.pinned = false,
    this.defaultOpen = false,

    // ── Parent (defaults) ──
    this.parentModule,

    // ── Device restrictions (no restriction by default) ──
    this.desktopOnly = false,
    this.mobileOnly = false,
    this.tabletOnly = false,
  });

  /// Safe getter for navigation route
  String get navigationRoute => route;

  /// Whether this item is visible on the given device
  bool isVisibleOnDevice(String deviceType) {
    if (desktopOnly && deviceType != 'desktop') return false;
    if (mobileOnly && deviceType != 'mobile') return false;
    if (tabletOnly && deviceType != 'tablet') return false;
    return true;
  }

  /// Whether this item has an active badge
  bool get hasBadge => badgeText != null || unreadCount > 0;

  /// Whether this item is a child module
  bool get isChildModule => parentModule != null && parentModule!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavItem &&
          runtimeType == other.runtimeType &&
          moduleKey == other.moduleKey;

  @override
  int get hashCode => moduleKey.hashCode;
}
