import 'package:flutter/material.dart';

import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/navigation/nav_item.dart';
import 'package:famhub_app/system/registry/module_registry.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

/// ============================================================
/// UNIFIED NAVIGATION BUILDER (ENTERPRISE GOVERNANCE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Build NavItem from SystemModule using registry metadata
///   - Single source of truth for navigation item creation
///   - Maps all governance fields from backend to NavItem
///   - Used by sidebar, bottom nav, dashboard, launcher, quick actions
///
/// ❌ Does NOT:
///   - Render widgets
///   - Apply access control (delegated to nav_config providers)
///   - Import Riverpod
///   - Hardcode module names, routes, or icons
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Consumes SystemModule (backend data) + ModuleRegistry (static metadata)
///   - Fully metadata-driven
///   - NO hardcoded module identifiers
/// ============================================================
class UnifiedNavBuilder {
  /// ============================================================
  /// BUILD NAV ITEM FROM SYSTEM MODULE
  /// ============================================================
  ///
  /// Converts a backend-driven SystemModule into a fully-governed NavItem.
  /// Uses ModuleRegistry to resolve icon and route metadata.
  /// Maps all governance fields (badge, device, grouping, etc.).
  ///
  /// [module] - The backend SystemModule to convert
  /// [unreadCount] - Optional unread/badge count (from notification service)
  /// Returns a NavItem with resolved presentation and governance data.
  /// ============================================================
  static NavItem buildNavItem(
    SystemModule module, {
    int unreadCount = 0,
  }) {
    // Resolve registry definition for this module
    final def = ModuleRegistry.byId(module.moduleKey);

    // Resolve icon from registry metadata (use iconKey or fallback)
    final iconKey = def?.iconKey ?? 'widgets';
    final iconData = IconResolver.resolve(iconKey);

    // Resolve badge color from badgeColor string
    final Color? resolvedBadgeColor;
    if (module.badgeColor != null) {
      resolvedBadgeColor = _resolveColor(module.badgeColor!);
    } else {
      resolvedBadgeColor = null;
    }

    // Resolve route from registry metadata
    final route = def?.entryRoute ?? '/${module.moduleKey}';

    return NavItem(
      moduleKey: module.moduleKey,
      displayName: module.displayName,
      route: route,
      icon: iconData,
      displayOrder: module.displayOrder,

      // ── Visibility ──
      sidebarVisible: module.sidebarVisible,
      bottomNavVisible: module.bottomNavVisible,
      dashboardVisible: module.dashboardVisible,
      quickActionVisible: module.quickActionVisible,
      launcherVisible: module.launcherVisible,

      // ── State ──
      isEnabled: module.isEnabled,
      maintenanceMode: module.maintenanceMode,
      maintenanceMessage: module.maintenanceMessage,

      // ── Sorting & grouping ──
      section: module.section,
      category: module.category,
      group: module.group,
      sortGroup: module.sortGroup,

      // ── Badge & notifications ──
      badgeText: module.badgeText,
      badgeColor: resolvedBadgeColor,
      notificationCountSource: module.notificationCountSource,
      unreadCount: unreadCount,

      // ── Favorites & Pins ──
      pinned: module.pinned,
      defaultOpen: module.defaultOpen,

      // ── Parent/child ──
      parentModule: module.parentModule,

      // ── Device restrictions ──
      desktopOnly: module.desktopOnly,
      mobileOnly: module.mobileOnly,
      tabletOnly: module.tabletOnly,
    );
  }

  /// ============================================================
  /// BUILD MULTIPLE NAV ITEMS (SAFE BATCH)
  /// ============================================================
  ///
  /// Converts a list of SystemModules to NavItems.
  /// Skips modules that fail validation.
  /// ============================================================
  static List<NavItem> buildNavItems(List<SystemModule> modules) {
    return modules
        .where((m) => m.isEnabled && !m.maintenanceMode)
        .map((m) => buildNavItem(m))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  /// ============================================================
  /// RESOLVE COLOR STRING TO COLOR
  /// ============================================================
  ///
  /// Converts a badge_color string (from backend) to a Color.
  /// Supported values: 'red', 'orange', 'amber', 'green',
  /// 'blue', 'purple', 'pink', 'grey'.
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

