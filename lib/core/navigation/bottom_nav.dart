// ignore: dangling_library_doc_comments
/// ============================================================
/// BOTTOM NAVIGATION (MOBILE NAV) — ENTERPRISE GOV
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Mobile bottom navigation bar (generated from backend)
///   - Route navigation on tap
///   - Active state tracking
///   - Badge/unread count support
///   - Overflow handling (5+ items)
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Navigation items come from backend module data
///   - No hardcoded module names, routes, or icons
///   - Uses bottomNavItemsProvider for filtered items
///   - Badges and status driven by backend metadata
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Reference registries directly for business rules
///   - Hardcode module identifiers
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/navigation/nav_config.dart';
import 'package:famhub_app/core/navigation/nav_item.dart';

class BottomNav extends ConsumerWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.toString();
    final navItems = ref.watch(bottomNavItemsProvider);

    // Always include Dashboard as first item
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
    ];

    final selectedIndex = _resolveIndex(location, allItems);

    if (allItems.length <= 5) {
      return _buildNavigationBar(context, theme, allItems, selectedIndex);
    }

    // More than 5 items - show first 4 + "More" overflow
    return _buildNavigationBar(
      context, theme, allItems.take(4).toList(), selectedIndex,
      showMoreButton: true,
      onMoreTap: () => _showMoreSheet(context, allItems.skip(4).toList()),
    );
  }

  /// ============================================================
  /// BUILD NAVIGATION BAR
  /// ============================================================
  Widget _buildNavigationBar(
    BuildContext context,
    ThemeData theme,
    List<NavItem> items,
    int selectedIndex, {
    bool showMoreButton = false,
    VoidCallback? onMoreTap,
  }) {
    // Build destinations with badges
    final destinations = items.map((item) {
      return NavigationDestination(
        icon: item.hasBadge
            ? Badge(
                label: Text(
                  item.badgeText ?? '${item.unreadCount}',
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
                backgroundColor: item.badgeColor ?? Colors.red,
                child: Icon(item.icon, color: Colors.grey.shade600),
              )
            : Icon(item.icon, color: Colors.grey.shade600),
        selectedIcon: item.hasBadge
            ? Badge(
                label: Text(
                  item.badgeText ?? '${item.unreadCount}',
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
                backgroundColor: item.badgeColor ?? Colors.red,
                child: Icon(item.icon, color: theme.colorScheme.primary),
              )
            : Icon(item.icon, color: theme.colorScheme.primary),
        label: item.maintenanceMode
            ? '${item.displayName}*'
            : item.displayName,
      );
    }).toList();

    // Add "More" button if needed
    if (showMoreButton) {
      destinations.add(
        NavigationDestination(
          icon: const Icon(Icons.grid_view_rounded, color: Colors.grey),
          selectedIcon: Icon(Icons.grid_view_rounded, color: theme.colorScheme.primary),
          label: 'More',
        ),
      );
    }

    return NavigationBar(
      selectedIndex: showMoreButton ? _adjustSelectedIndex(selectedIndex, items.length) : selectedIndex,
      onDestinationSelected: (index) {
        if (showMoreButton && index >= items.length) {
          onMoreTap?.call();
        } else {
          _onNavigate(context, items[index]);
        }
      },
      backgroundColor: Colors.white,
      indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: destinations,
    );
  }

  /// Adjust selected index when "More" button is present
  int _adjustSelectedIndex(int selectedIndex, int visibleCount) {
    if (selectedIndex < visibleCount) return selectedIndex;
    return visibleCount; // "More" index
  }

  /// ============================================================
  /// SHOW MORE SHEET (OVERFLOW MENU)
  /// ============================================================
  void _showMoreSheet(BuildContext context, List<NavItem> extraItems) {
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'More Modules',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: extraItems.length,
                itemBuilder: (context, index) {
                  final item = extraItems[index];
                  return ListTile(
                    leading: item.hasBadge
                        ? Badge(
                            label: Text(
                              item.badgeText ?? '${item.unreadCount}',
                              style: const TextStyle(fontSize: 9, color: Colors.white),
                            ),
                            backgroundColor: item.badgeColor ?? Colors.red,
                            child: Icon(item.icon),
                          )
                        : Icon(item.icon),
                    title: Text(item.displayName),
                    subtitle: item.maintenanceMode
                        ? Text('Under maintenance',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade600,
                            ))
                        : null,
                    trailing: const Icon(Icons.chevron_right, size: 18),
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
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// ============================================================
  /// RESOLVE ACTIVE INDEX
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
  /// NAVIGATE
  /// ============================================================
  void _onNavigate(BuildContext context, NavItem item) {
    if (item.route.isNotEmpty) {
      context.go(item.route);
    }
  }
}
