/// ============================================================
/// SHELL NAVIGATION RAIL — Material 3 NavigationRail for tablet
/// ============================================================
///
/// 🎯 PURPOSE:
///   Replace ShellSidebar in the tablet layout with a Material 3
///   NavigationRail, aligning with platform standards.
///
/// ✅ Design Principles:
///   - Uses Material 3 NavigationRail (extended: false, labels shown)
///   - Consumes the same sidebarNavItemsProvider as ShellSidebar
///   - All colors come from ShellThemeColors — no hardcoded colors
///   - Supports badges, runtime enable/disable, feature flags,
///     context filtering from the provider (no reimplementation)
///   - Domains-agnostic — no hardcoded modules or icons
///   - Scrollable when needed
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/shell_theme.dart';
import 'nav_item.dart';
import 'nav_config.dart';

/// ============================================================
/// SHELL NAVIGATION RAIL — Material 3 tablet navigation
/// ============================================================
///
/// Consumes sidebarNavItemsProvider (same as ShellSidebar) and
/// renders a Material 3 NavigationRail with:
/// - extended: false (fixed to icon + label)
/// - Labels always shown
/// - Current route highlighting
/// - Badge support
/// - Scrollable when items overflow
/// - No hardcoded modules, colors, or routing logic
/// ============================================================
class ShellNavigationRail extends ConsumerWidget {
  const ShellNavigationRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;
    final location = GoRouterState.of(context).uri.toString();
    final navItems = ref.watch(sidebarNavItemsProvider);

    // Build all items with Dashboard first (matching ShellSidebar behavior)
    final allItems = [
      const NavItem(
        moduleKey: 'dashboard',
        displayName: 'Dashboard',
        route: '/',
        icon: Icons.dashboard_rounded,
        displayOrder: 0,
      ),
      ...navItems,
    ];

    final selectedIndex = _resolveIndex(location, allItems);

    return Container(
      color: palette.navigationBg,
      child: SingleChildScrollView(
        child: SizedBox(
          width: 80, // Standard NavigationRail width
          child: NavigationRail(
            extended: false,
            labelType: NavigationRailLabelType.all,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) {
              if (index >= 0 && index < allItems.length) {
                _onNavigate(context, allItems[index]);
              }
            },
            backgroundColor: Colors.transparent,
            indicatorColor: palette.navigationSelectedBg,
            selectedIconTheme: IconThemeData(
              color: palette.navigationSelectedText,
              size: 24,
            ),
            unselectedIconTheme: IconThemeData(
              color: palette.secondaryText,
              size: 24,
            ),
            selectedLabelTextStyle: TextStyle(
              color: palette.navigationSelectedText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: palette.secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            leading: _buildBrandIcon(palette),
            destinations: allItems.map((item) {
              final isMaintenance = item.maintenanceMode;
              final isDisabled = !item.isEnabled;

              final iconWidget = Icon(
                item.icon,
                size: 24,
              );

              final selectedIconWidget = Icon(
                item.icon,
                size: 24,
              );

              final Widget effectiveIcon;
              final Widget effectiveSelectedIcon;

              if (item.hasBadge) {
                final badgeLabel = item.badgeText ?? '${item.unreadCount}';
                effectiveIcon = Badge(
                  label: Text(
                    badgeLabel,
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                  child: isMaintenance || isDisabled
                      ? Icon(item.icon, color: palette.tertiaryText)
                      : iconWidget,
                );
                effectiveSelectedIcon = Badge(
                  label: Text(
                    badgeLabel,
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                  child: selectedIconWidget,
                );
              } else {
                effectiveIcon = isMaintenance || isDisabled
                    ? Icon(item.icon, color: palette.tertiaryText)
                    : iconWidget;
                effectiveSelectedIcon = selectedIconWidget;
              }

              return NavigationRailDestination(
                icon: effectiveIcon,
                selectedIcon: effectiveSelectedIcon,
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMaintenance
                          ? '${item.displayName}*'
                          : item.displayName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (isMaintenance)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: palette.warning,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                disabled: !item.isEnabled || item.maintenanceMode,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// BRAND ICON
  /// ============================================================
  ///
  /// Renders a small brand icon at the top of the navigation rail,
  /// matching the branding consistency but in a compact form.
  /// ============================================================
  Widget _buildBrandIcon(ShellColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: palette.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.grid_view_rounded, // Neutral icon — no agriculture
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// ============================================================
  /// RESOLVE INDEX — Match current route to nav item
  /// ============================================================
  ///
  /// Identical logic to ShellSidebar._resolveIndex.
  /// Does NOT introduce new routing logic.
  /// ============================================================
  int _resolveIndex(String location, List<NavItem> items) {
    for (int i = 0; i < items.length; i++) {
      if (items[i].route == '/') {
        if (location == '/' || location == '') return i;
      } else if (location.startsWith(items[i].route)) {
        return i;
      }
    }
    return 0;
  }

  /// ============================================================
  /// NAVIGATE — Go to item route
  /// ============================================================
  ///
  /// Identical behavior to ShellSidebar._onNavigate.
  /// Does NOT introduce new routing logic.
  /// ============================================================
  void _onNavigate(BuildContext context, NavItem item) {
    if (item.route.isNotEmpty) {
      context.go(item.route);
    }
  }
}
