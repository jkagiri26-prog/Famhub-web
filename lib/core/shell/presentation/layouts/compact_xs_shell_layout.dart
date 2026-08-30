/// ============================================================
/// COMPACT XS SHELL LAYOUT (<360px)
/// ============================================================
///
/// Ultra-compact layout for very small screens (<360px).
/// No chrome — just content and minimal navigation.
/// Extracted from UnifiedAppShellV2 for modularity.
///
/// ✅ Performance:
///   - Each region uses ShellRegion for independent rebuild
///   - Extension slots for future extensions
///   - const constructors throughout
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/shell_config.dart';
import '../../../theme/shell_theme.dart';
import '../../../navigation/nav_config.dart';
import '../../../navigation/nav_item.dart';
import '../widgets/shell_region.dart';
import 'common/maintenance_banner.dart';
/// ============================================================
/// COMPACT XS SHELL LAYOUT
/// ============================================================
///
/// Used for very small screens (<360px).
/// Features: no top bar, no FABs, compact bottom nav only.
/// ============================================================
class CompactXsShellLayout extends StatelessWidget {
  final Widget child;
  final ShellConfig config;
  final ShellColorPalette palette;

  const CompactXsShellLayout({
    super.key,
    required this.child,
    required this.config,
    required this.palette,
  });
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            ShellRegion(
              name: 'maintenanceBanner',
              visible: config.showMaintenanceBanner,
              child: const MaintenanceBanner(),
            ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: config.navigation.visible
          ? const _CompactBottomNav()
          : null,
    );
  }
}

/// ============================================================
/// COMPACT BOTTOM NAV — Runtime-driven, no hardcoded items
/// ============================================================
///
/// Ultra-compact bottom navigation with no labels, only icons.
/// Items are supplied by dashboardNavItemsProvider — the same runtime
/// source used by MobileShellLayout via ShellBottomNav.
/// ============================================================
class _CompactBottomNav extends ConsumerWidget {
  const _CompactBottomNav();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;
    final location = GoRouterState.of(context).uri.toString();
    final navItems = ref.watch(dashboardNavItemsProvider);

    // Always include Dashboard as first item (same pattern as ShellBottomNav),
    // then modules, then an explicit Profile destination.
    final allItems = [
      const NavItem(
        moduleKey: 'dashboard',
        displayName: 'Home',
        route: '/',
        icon: Icons.home_rounded,
        displayOrder: 0,
        bottomNavVisible: true,
      ),
      ...navItems,
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

    final selectedIndex = _resolveIndex(location, allItems);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.border.withValues(alpha: 0.5)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            allItems.length,
            (index) {
              final item = allItems[index];
              final isSelected = index == selectedIndex;

              return IconButton(
                onPressed: () => _onNavigate(context, item),
                icon: item.hasBadge
                    ? Badge(
                        label: Text(
                          item.badgeText ?? '${item.unreadCount}',
                          style: const TextStyle(fontSize: 9, color: Colors.white),
                        ),
                        child: Icon(
                          item.icon,
                          size: 20,
                          color: isSelected ? palette.primary : palette.secondaryText,
                        ),
                      )
                    : Icon(
                        item.icon,
                        size: 20,
                        color: isSelected ? palette.primary : palette.secondaryText,
                      ),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                splashRadius: 18,
                tooltip: item.displayName,
              );
            },
          ),
        ),
      ),
    );
  }

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

  void _onNavigate(BuildContext context, NavItem item) {
    if (item.route.isNotEmpty) {
      context.go(item.route);
    }
  }
}

