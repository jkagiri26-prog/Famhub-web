/// ============================================================
/// ANIMATED SIDE NAVIGATION (ENTERPRISE GOVERNANCE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/navigation/ = navigation layer
///
/// ✅ Responsibilities:
///   - Animated sidebar with smooth expand/collapse (~200ms)
///   - Labels fade in/out during transition
///   - Icons animate position
///   - Consumes SidebarController for state
///   - Uses NavItemContainer for consistent hover/focus
///   - No rebuild of dashboard content during animation
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Navigation items come from backend module data
///   - No hardcoded module names, routes, or icons
///   - Uses sidebarNavItemsProvider for filtered items
///   - No business logic duplication
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/navigation/nav_config.dart';
import 'package:famhub_app/core/navigation/nav_item.dart';
import 'package:famhub_app/core/navigation/nav_item_styles.dart';
import 'package:famhub_app/core/shell/sidebar_controller.dart';

/// ============================================================
/// ANIMATED SIDE NAV
/// ============================================================
class AnimatedSideNav extends ConsumerWidget {
  const AnimatedSideNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebarState = ref.watch(sidebarControllerProvider);
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

    final bool isExpanded = sidebarState.isExpanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isExpanded
          ? SidebarState.expandedWidth
          : SidebarState.collapsedWidth,
      color: Colors.white,
      child: Column(
        children: [
          // ── Brand Header ──
          _AnimatedBrandHeader(isExpanded: isExpanded, theme: theme),

          const Divider(height: 1, color: Colors.transparent),

          // ── Navigation List ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ── Pinned section ──
                if (pinnedItems.isNotEmpty && isExpanded) ...[
                  _buildSectionLabel('Pinned', theme),
                  ...pinnedItems.map((item) {
                    final idx = allItems.indexOf(item);
                    return _AnimatedSidebarListItem(
                      item: item,
                      isSelected: idx == selectedIndex,
                      isExpanded: isExpanded,
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
                  return _AnimatedSidebarListItem(
                    item: item,
                    isSelected: idx == selectedIndex,
                    isExpanded: isExpanded,
                    onTap: () => _onNavigate(context, item),
                  );
                }),

                // ── Collapsed items (show all as icons) ──
                if (!isExpanded) ...[
                  ...pinnedItems.map((item) {
                    final idx = allItems.indexOf(item);
                    return _AnimatedSidebarListItem(
                      item: item,
                      isSelected: idx == selectedIndex,
                      isExpanded: isExpanded,
                      onTap: () => _onNavigate(context, item),
                    );
                  }),
                  ...regularItems.map((item) {
                    final idx = allItems.indexOf(item);
                    return _AnimatedSidebarListItem(
                      item: item,
                      isSelected: idx == selectedIndex,
                      isExpanded: isExpanded,
                      onTap: () => _onNavigate(context, item),
                    );
                  }),
                ],
              ],
            ),
          ),

          // ── Collapse toggle button ──
          _CollapseToggle(isExpanded: isExpanded),
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

/// ============================================================
/// ANIMATED BRAND HEADER
/// ============================================================
class _AnimatedBrandHeader extends StatelessWidget {
  final bool isExpanded;
  final ThemeData theme;

  const _AnimatedBrandHeader({
    required this.isExpanded,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: 20,
        horizontal: isExpanded ? 20 : 0,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: isExpanded
          ? Row(
              children: [
                _buildBrandIcon(),
                const SizedBox(width: 12),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isExpanded ? 1.0 : 0.0,
                  child: Text(
                    'FAMHUB',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            )
          : Center(child: _buildBrandIcon()),
    );
  }

  Widget _buildBrandIcon() {
    return Container(
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
    );
  }
}

/// ============================================================
/// ANIMATED SIDEBAR LIST ITEM
/// ============================================================
///
/// A single navigation item with animated label and icon.
/// Uses NavItemContainer for consistent hover/focus/selected states.
/// ============================================================
class _AnimatedSidebarListItem extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _AnimatedSidebarListItem({
    required this.item,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isExpanded) {
      return NavItemContainer(
        isSelected: isSelected,
        isDisabled: !item.isEnabled,
        isMaintenance: item.maintenanceMode,
        onTap: (item.isEnabled && !item.maintenanceMode) ? onTap : null,
        child: Row(
          children: [
            // ── Icon with optional maintenance indicator ──
            _buildIcon(theme),
            const SizedBox(width: 12),

            // ── Title with animation ──
            Expanded(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isExpanded ? 1.0 : 0.0,
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
            ),

            // ── Badge ──
            if (item.hasBadge)
              _buildBadge(),

            const SizedBox(width: 8),

            // ── Active indicator ──
            NavItemIndicator(isSelected: isSelected),
          ],
        ),
      );
    }

    // Collapsed: icon-only with tooltip
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Tooltip(
        message: item.maintenanceMode
            ? '${item.displayName} (maintenance)'
            : item.displayName,
        child: NavItemContainer(
          isSelected: isSelected,
          isDisabled: !item.isEnabled,
          isMaintenance: item.maintenanceMode,
          onTap: (item.isEnabled && !item.maintenanceMode) ? onTap : null,
          padding: const EdgeInsets.symmetric(vertical: 12),
          width: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildIcon(theme),
              // ── Badge (top-right) ──
              if (item.hasBadge)
                Positioned(
                  top: -4,
                  right: 0,
                  child: _buildMiniBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ThemeData theme) {
    final colors = NavItemStyleResolver.resolve(
      theme: theme,
      interaction: isSelected
          ? NavItemInteraction.selected
          : item.maintenanceMode
              ? NavItemInteraction.maintenance
              : NavItemInteraction.idle,
    );

    return Stack(
      children: [
        Icon(
          item.icon,
          size: 20,
          color: colors.iconColor,
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
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
    );
  }

  Widget _buildMiniBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
    );
  }
}

/// ============================================================
/// COLLAPSE TOGGLE BUTTON
/// ============================================================
class _CollapseToggle extends ConsumerWidget {
  final bool isExpanded;

  const _CollapseToggle({required this.isExpanded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: isExpanded
          ? SizedBox(
              width: double.infinity,
              child: NavItemContainer(
                onTap: () => ref.read(sidebarControllerProvider.notifier).collapse(),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_open_rounded,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Collapse',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : NavItemContainer(
              onTap: () => ref.read(sidebarControllerProvider.notifier).expand(),
              padding: const EdgeInsets.symmetric(vertical: 10),
              width: 72,
              child: Center(
                child: Icon(
                  Icons.menu_rounded,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
    );
  }
}
