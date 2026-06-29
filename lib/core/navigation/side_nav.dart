// ignore: dangling_library_doc_comments
/// ============================================================
/// SIDE NAVIGATION (TABLET/DESKTOP NAV) — ENTERPRISE GOV
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Tablet/Desktop side navigation (generated from backend)
///   - Module navigation via backend registry
///   - Active state tracking
///   - Collapsible mode
///   - Badge/unread counts
///   - Pinned modules
///   - Maintenance mode indicators
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Navigation items come from backend module data
///   - No hardcoded module names, routes, or icons
///   - Uses sidebarNavItemsProvider for filtered items
///   - Badges, pins, and status all driven by backend metadata
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Hardcode module identifiers
///   - Bypass ModuleService or Context Engine
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/navigation/nav_config.dart';
import 'package:famhub_app/core/navigation/nav_item.dart';

class SideNav extends ConsumerWidget {
  final bool isCollapsed;

  const SideNav({
    super.key,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.toString();
    final sidebarItems = ref.watch(sidebarNavItemsProvider);

    // Always include the dashboard Home item first
    final allItems = [
      const NavItem(
        moduleKey: 'dashboard',
        displayName: 'Dashboard',
        route: '/',
        icon: Icons.dashboard_rounded,
        displayOrder: 0,
      ),
      ...sidebarItems,
    ];

    // Separate pinned items from the rest
    final pinnedItems = allItems.where((item) => item.pinned).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final regularItems = allItems.where((item) => !item.pinned).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final selectedIndex = _resolveIndex(location, allItems);

    if (isCollapsed) {
      return _buildCollapsedSidebar(context, theme, allItems, selectedIndex);
    }

    return _buildExpandedSidebar(
      context, theme, pinnedItems, regularItems, allItems, selectedIndex);
  }

  /// ============================================================
  /// EXPANDED SIDEBAR (DEFAULT DESKTOP)
  /// ============================================================
  Widget _buildExpandedSidebar(
    BuildContext context,
    ThemeData theme,
    List<NavItem> pinnedItems,
    List<NavItem> regularItems,
    List<NavItem> allItems,
    int selectedIndex,
  ) {
    return Container(
      width: 260,
      color: Colors.white,
      child: Column(
        children: [
          // ── Brand Header ──
          _buildBrandHeader(theme),
          const Divider(height: 1, color: Colors.transparent),

          // ── Navigation List ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ── Pinned section ──
                if (pinnedItems.isNotEmpty) ...[
                  _buildSectionLabel('Pinned', theme),
                  ...pinnedItems.map((item) {
                    final idx = allItems.indexOf(item);
                    return _SidebarListItem(
                      item: item,
                      isSelected: idx == selectedIndex,
                      onTap: () => _onNavigate(context, item),
                    );
                  }),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Divider(height: 1),
                  ),
                ],

                // ── Regular items ──
                ...regularItems.map((item) {
                  final idx = allItems.indexOf(item);
                  return _SidebarListItem(
                    item: item,
                    isSelected: idx == selectedIndex,
                    onTap: () => _onNavigate(context, item),
                  );
                }),
              ],
            ),
          ),

          // ── Bottom spacer ──
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.agriculture_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'FAMHUB',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  /// ============================================================
  /// COLLAPSED SIDEBAR (TABLET / COLLAPSED STATE)
  /// ============================================================
  Widget _buildCollapsedSidebar(
    BuildContext context,
    ThemeData theme,
    List<NavItem> items,
    int selectedIndex,
  ) {
    return Container(
      width: 72,
      color: Colors.white,
      child: Column(
        children: [
          // ── Brand Icon ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.agriculture_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          // ── Navigation Icons ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;
                return _SidebarIconItem(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => _onNavigate(context, item),
                );
              },
            ),
          ),
        ],
      ),
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

/// ============================================================
/// SIDEBAR LIST ITEM (EXPANDED) — WITH BADGE SUPPORT
/// ============================================================
class _SidebarListItem extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarListItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // ── Icon with optional maintenance indicator ──
                Stack(
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.grey.shade600,
                    ),
                    if (item.maintenanceMode)
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // ── Title ──
                Expanded(
                  child: Text(
                    item.displayName,
                    style: TextStyle(
                      fontSize: 14,
                      decoration: item.maintenanceMode
                          ? TextDecoration.lineThrough
                          : null,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : item.maintenanceMode
                              ? Colors.grey.shade400
                              : Colors.black87,
                    ),
                  ),
                ),
                // ── Badge ──
                if (item.hasBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: item.badgeColor ?? Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.badgeText ?? '${item.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // ── Active indicator ──
                if (isSelected)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// SIDEBAR ICON ITEM (COLLAPSED) — WITH BADGE SUPPORT
/// ============================================================
class _SidebarIconItem extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarIconItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: item.maintenanceMode
            ? '${item.displayName} (maintenance)'
            : item.displayName,
        child: Material(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 72,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    item.icon,
                    size: 20,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : item.maintenanceMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                  ),
                  // ── Badge (top-right) ──
                  if (item.hasBadge)
                    Positioned(
                      top: 4,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: item.badgeColor ?? Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.badgeText ?? '${item.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
