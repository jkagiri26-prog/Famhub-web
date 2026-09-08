/// ============================================================
/// SHELL BOTTOM NAV — Domain-agnostic bottom navigation bar
/// ============================================================
///
/// 🎯 PURPOSE:
///   Replace agriculture-specific BottomNav with a neutral,
///   configurable bottom navigation bar. All colors from ShellTheme.
///
/// ✅ Domain-Agnostic:
///   - No hardcoded colors or agriculture-specific icons
///   - Configurable max items before overflow
///   - Badge counts from backend data
///   - Consumes ShellTheme for all colors
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/module_provider.dart';
import '../theme/shell_theme.dart';
import '../workspace/application/workspace_dashboard_provider.dart';
import 'nav_item.dart';
import 'nav_config.dart';

/// Mobile bottom-nav label overrides.
/// Only affects the compact mobile navigation label — the underlying
/// module name in system.modules is left unchanged.
const Map<String, String> _bottomNavLabelOverrides = <String, String>{
  'farm_management': 'Farm',
};

String _bottomNavLabel(NavItem item) =>
    _bottomNavLabelOverrides[item.moduleKey] ?? item.displayName;

/// ============================================================
/// SHELL BOTTOM NAV — Replaces BottomNav
/// ============================================================
class ShellBottomNav extends ConsumerWidget {
  final int maxItems;

  const ShellBottomNav({super.key, this.maxItems = 5});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;
    final location = GoRouterState.of(context).uri.toString();
    final navItems = ref.watch(dashboardNavItemsProvider);
    final moduleCount = ref
            .watch(moduleProvider)
            .whenOrNull(data: (m) => m.length) ??
        0;

    // ── Fixed workspace-model navigation: 5 positions ──
    //   1. Home (global)          → /home
    //   2. Marketplace (global)   → /marketplace
    //   3. Workspace Dashboard    → '/'  (dynamic, follows active workspace)
    //   4. Traceability (global)  → /traceability
    //   5. More (global)          → sheet of remaining modules
    final wsType = ref.watch(activeWorkspaceTypeProvider);
    final workspaceItem = _workspaceNavItem(wsType);

    final fixedItems = [
      const NavItem(
        moduleKey: 'home',
        displayName: 'Home',
        route: '/home',
        icon: Icons.home_rounded,
        displayOrder: 0,
        bottomNavVisible: true,
      ),
      const NavItem(
        moduleKey: 'marketplace',
        displayName: 'Marketplace',
        route: '/marketplace',
        icon: Icons.storefront_outlined,
        displayOrder: 1,
        bottomNavVisible: true,
      ),
      workspaceItem,
      const NavItem(
        moduleKey: 'traceability',
        displayName: 'Traceability',
        route: '/traceability',
        icon: Icons.qr_code,
        displayOrder: 3,
        bottomNavVisible: true,
      ),
    ];

    // Everything else (modules not pinned globally and not the current
    // workspace dashboard) lives behind the fixed "More" destination.
    // Opening a module from More NEVER switches the workspace/context.
    final excluded = <String>{
      'marketplace',
      'traceability',
      workspaceItem.moduleKey,
    };
    final extraItems = <NavItem>[
      for (final item in navItems)
        if (!excluded.contains(item.moduleKey)) item,
      if (!navItems.any((i) => i.moduleKey == 'profile'))
        const NavItem(
          moduleKey: 'profile',
          displayName: 'Profile',
          route: '/profile',
          icon: Icons.person_outline,
          displayOrder: 999,
          bottomNavVisible: true,
        ),
    ];

    final selectedIndex = _resolveFixedIndex(location, fixedItems, extraItems);

    return _buildNavBar(
      context, palette, fixedItems, selectedIndex,
      showMoreButton: true,
      extraItems: extraItems,
      moduleCount: moduleCount,
    );
  }

  /// Build the dynamic third destination for the active workspace.
  ///
  /// Home is NOT the workspace dashboard. The third position is the
  /// workspace dashboard ('/'), rendered through the existing dynamic
  /// dashboard architecture (UnifiedDashboardHost).
  NavItem _workspaceNavItem(String? wsType) {
    switch (wsType) {
      case 'farmer':
        return const NavItem(
          moduleKey: 'farm_management',
          displayName: 'Farm',
          route: '/',
          icon: Icons.agriculture_outlined,
          displayOrder: 2,
          bottomNavVisible: true,
        );
      case 'trader':
        return const NavItem(
          moduleKey: 'trader',
          displayName: 'Trader',
          route: '/',
          icon: Icons.business_outlined,
          displayOrder: 2,
          bottomNavVisible: true,
        );
      case 'institution':
        return const NavItem(
          moduleKey: 'finance',
          displayName: 'Institutions',
          route: '/',
          icon: Icons.account_balance_outlined,
          displayOrder: 2,
          bottomNavVisible: true,
        );
      default:
        return const NavItem(
          moduleKey: 'dashboard',
          displayName: 'Dashboard',
          route: '/',
          icon: Icons.dashboard_outlined,
          displayOrder: 2,
          bottomNavVisible: true,
        );
    }
  }

  /// Resolve the selected destination. Routes belonging to the More
  /// sheet select the More destination (index == fixedItems.length).
  int _resolveFixedIndex(
    String location,
    List<NavItem> fixedItems,
    List<NavItem> extraItems,
  ) {
    for (int i = 0; i < fixedItems.length; i++) {
      final item = fixedItems[i];
      if (_matchesRoute(location, item.route)) return i;
    }
    for (final item in extraItems) {
      if (_matchesRoute(location, item.route)) {
        return fixedItems.length; // More
      }
    }
    return 0;
  }

  bool _matchesRoute(String location, String route) {
    if (route == '/') {
      return location == '/' || location.isEmpty;
    }
    return location == route || location.startsWith('$route/');
  }

  Widget _buildNavBar(
    BuildContext context,
    ShellColorPalette palette,
    List<NavItem> items,
    int selectedIndex, {
    bool showMoreButton = false,
    List<NavItem> extraItems = const [],
    int moduleCount = 0,
  }) {
    final destinations = items.map((item) {
      return NavigationDestination(
        icon: item.hasBadge
            ? Badge(
                label: Text(
                  item.badgeText ?? '${item.unreadCount}',
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
                child: Icon(item.icon, color: palette.secondaryText),
              )
            : Icon(item.icon, color: palette.secondaryText),
        selectedIcon: item.hasBadge
            ? Badge(
                label: Text(
                  item.badgeText ?? '${item.unreadCount}',
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
                child: Icon(item.icon, color: palette.navigationSelectedText),
              )
            : Icon(item.icon, color: palette.navigationSelectedText),
        label: item.maintenanceMode
            ? '${_bottomNavLabel(item)}*'
            : _bottomNavLabel(item),
      );
    }).toList();

    if (showMoreButton) {
      destinations.add(
        NavigationDestination(
          icon: Icon(Icons.grid_view_rounded, color: palette.secondaryText),
          selectedIcon: Icon(Icons.grid_view_rounded,
              color: palette.navigationSelectedText),
          label: 'More',
        ),
      );
    }

    return NavigationBar(
      selectedIndex: showMoreButton
          ? (selectedIndex < items.length ? selectedIndex : items.length)
          : selectedIndex,
      onDestinationSelected: (index) {
        if (showMoreButton && index >= items.length) {
          _showMoreSheet(context, extraItems, palette,
              moduleCount: moduleCount);
        } else {
          _onNavigate(context, items[index]);
        }
      },
      backgroundColor: palette.surface,
      indicatorColor: palette.navigationSelectedBg,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: destinations,
    );
  }

  void _showMoreSheet(
      BuildContext context, List<NavItem> extraItems, ShellColorPalette palette,
      {int moduleCount = 0}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: palette.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'More',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.primaryText,
                      ),
                    ),
                    if (moduleCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '$moduleCount services',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.secondaryText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: extraItems.length,
                  itemBuilder: (context, index) {
                    final item = extraItems[index];
                    return ListTile(
                      leading: item.hasBadge
                          ? Badge(
                              label: Text(
                                item.badgeText ?? '${item.unreadCount}',
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.white),
                              ),
                              child: Icon(item.icon, color: palette.secondaryText),
                            )
                          : Icon(item.icon, color: palette.secondaryText),
                      title: Text(
                        _bottomNavLabel(item),
                        style: TextStyle(color: palette.primaryText),
                      ),
                      subtitle: item.maintenanceMode
                          ? Text(
                              'Under maintenance',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.warning,
                              ),
                            )
                          : null,
                      trailing: Icon(Icons.chevron_right,
                          size: 18, color: palette.secondaryText),
                      enabled: !item.maintenanceMode,
                      onTap: item.maintenanceMode
                          ? null
                          : () {
                              Navigator.pop(context);
                              _onNavigate(context, item);
                            },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _onNavigate(BuildContext context, NavItem item) {
    if (item.route.isNotEmpty) {
      context.go(item.route);
    }
  }
}
