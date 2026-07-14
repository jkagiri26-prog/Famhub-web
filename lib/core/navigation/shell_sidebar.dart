/// ============================================================
/// SHELL SIDEBAR — Domain-agnostic animated sidebar navigation
/// ============================================================
///
/// 🎯 PURPOSE:
///   Replace agriculture-specific AnimatedSideNav with a neutral,
///   configurable sidebar. All colors come from ShellTheme.
///   No hardcoded brand name, icons, or colors.
///
/// ✅ Domain-Agnostic:
///   - Brand logo/name come from ShellTheme.brand
///   - No Icons.agriculture or similar agriculture-specific icons
///   - Neutral indigo/blue default selection color
///   - Smooth expand/collapse animation (200ms)
///   - Consumes ShellTheme for all colors
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/shell_theme.dart';
import '../theme/shell_theme_provider.dart';
import '../shell/application/controllers/sidebar_controller.dart';
import 'nav_item.dart';
import 'nav_config.dart';
import 'shell_nav_item.dart';

/// ============================================================
/// SHELL SIDEBAR — Replaces AnimatedSideNav
/// ============================================================
class ShellSidebar extends ConsumerWidget {
  final bool showPinnedSection;
  final bool showSectionLabels;
  final bool collapsible;

  const ShellSidebar({
    super.key,
    this.showPinnedSection = true,
    this.showSectionLabels = true,
    this.collapsible = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;
    final location = GoRouterState.of(context).uri.toString();
    final brandName = ref.watch(shellThemeProvider).brand.name;
    final sidebarItems = ref.watch(sidebarNavItemsProvider);

    // Build all items with Dashboard first
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

    // Separate pinned from regular
    final pinnedItems = allItems.where((item) => item.pinned).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final regularItems = allItems.where((item) => !item.pinned).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final selectedIndex = _resolveIndex(location, allItems);

    // ── When collapsible is false: always expanded, no toggle ──
    if (!collapsible) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: SidebarState.expandedWidth,
        color: palette.navigationBg,
        child: Column(
          children: [
            _BrandHeader(
              isExpanded: true,
              palette: palette,
              brandName: ref.watch(shellThemeProvider).brand.name,
            ),
            const Divider(height: 1, color: Colors.transparent),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (showPinnedSection && pinnedItems.isNotEmpty) ...[
                    _SectionLabel('Pinned', palette),
                    ...pinnedItems.map((item) {
                      final idx = allItems.indexOf(item);
                      return _SidebarItem(
                        item: item,
                        isSelected: idx == selectedIndex,
                        isExpanded: true,
                        palette: palette,
                        onTap: () => _onNavigate(context, item),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Divider(height: 1, color: palette.divider),
                    ),
                  ],
                  ...regularItems.map((item) {
                    final idx = allItems.indexOf(item);
                    return _SidebarItem(
                      item: item,
                      isSelected: idx == selectedIndex,
                      isExpanded: true,
                      palette: palette,
                      onTap: () => _onNavigate(context, item),
                    );
                  }),
                ],
              ),
            ),
            // No collapse toggle when collapsible is false
          ],
        ),
      );
    }

    // ── Collapsible behavior: watch sidebar state, show toggle ──
    final sidebarState = ref.watch(sidebarControllerProvider);
    final isExpanded = sidebarState.isExpanded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isExpanded
          ? SidebarState.expandedWidth
          : SidebarState.collapsedWidth,
      color: palette.navigationBg,
      child: Column(
        children: [
          // ── Brand Header ──
          _BrandHeader(
            isExpanded: isExpanded,
            palette: palette,
            brandName: brandName,
          ),

          const Divider(height: 1, color: Colors.transparent),

          // ── Navigation List ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ── Pinned section ──
                if (showPinnedSection && pinnedItems.isNotEmpty && isExpanded) ...[
                  _SectionLabel('Pinned', palette),
                  ...pinnedItems.map((item) {
                    final idx = allItems.indexOf(item);
                    return _SidebarItem(
                      item: item,
                      isSelected: idx == selectedIndex,
                      isExpanded: isExpanded,
                      palette: palette,
                      onTap: () => _onNavigate(context, item),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Divider(height: 1, color: palette.divider),
                  ),
                ],

                // ── Regular items ──
                ...regularItems.map((item) {
                  final idx = allItems.indexOf(item);
                  return _SidebarItem(
                    item: item,
                    isSelected: idx == selectedIndex,
                    isExpanded: isExpanded,
                    palette: palette,
                    onTap: () => _onNavigate(context, item),
                  );
                }),

                // ── Collapsed items (show all as icons) ──
                if (!isExpanded) ...[
                  ...pinnedItems.map((item) {
                    final idx = allItems.indexOf(item);
                    return _SidebarItem(
                      item: item,
                      isSelected: idx == selectedIndex,
                      isExpanded: isExpanded,
                      palette: palette,
                      onTap: () => _onNavigate(context, item),
                    );
                  }),
                  ...regularItems.map((item) {
                    final idx = allItems.indexOf(item);
                    return _SidebarItem(
                      item: item,
                      isSelected: idx == selectedIndex,
                      isExpanded: isExpanded,
                      palette: palette,
                      onTap: () => _onNavigate(context, item),
                    );
                  }),
                ],
              ],
            ),
          ),

          // ── Collapse toggle ──
          _CollapseToggle(isExpanded: isExpanded, palette: palette),
        ],
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
/// BRAND HEADER
/// ============================================================
///
/// Renders the brand logo/icon and name from ShellTheme.
/// No agriculture-specific icons or hardcoded names.
/// ============================================================
class _BrandHeader extends StatelessWidget {
  final bool isExpanded;
  final ShellColorPalette palette;
  final String brandName;

  const _BrandHeader({
    required this.isExpanded,
    required this.palette,
    required this.brandName,
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
          bottom: BorderSide(color: palette.divider),
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
                    brandName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
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
        color: palette.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.grid_view_rounded, // Neutral icon — no agriculture
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

/// ============================================================
/// SECTION LABEL
/// ============================================================
class _SectionLabel extends StatelessWidget {
  final String label;
  final ShellColorPalette palette;

  const _SectionLabel(this.label, this.palette);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: palette.tertiaryText,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// ============================================================
/// SIDEBAR ITEM
/// ============================================================
class _SidebarItem extends StatelessWidget {
  final NavItem item;
  final bool isSelected;
  final bool isExpanded;
  final ShellColorPalette palette;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.isSelected,
    required this.isExpanded,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isExpanded) {
      return ShellNavItemContainer(
        isSelected: isSelected,
        isDisabled: !item.isEnabled,
        isMaintenance: item.maintenanceMode,
        onTap: (item.isEnabled && !item.maintenanceMode) ? onTap : null,
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
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
                        ? palette.navigationSelectedText
                        : item.maintenanceMode
                            ? palette.tertiaryText
                            : palette.primaryText,
                  ),
                ),
              ),
            ),
            if (item.hasBadge)
              ShellNavBadge(
                text: item.badgeText ?? '${item.unreadCount}',
                color: item.badgeColor,
              ),
            const SizedBox(width: 8),
            ShellNavIndicator(isSelected: isSelected),
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
        child: ShellNavItemContainer(
          isSelected: isSelected,
          isDisabled: !item.isEnabled,
          isMaintenance: item.maintenanceMode,
          onTap: (item.isEnabled && !item.maintenanceMode) ? onTap : null,
          padding: const EdgeInsets.symmetric(vertical: 12),
          width: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _buildIcon(),
              if (item.hasBadge)
                Positioned(
                  top: -4,
                  right: 0,
                  child: ShellNavBadge(
                    text: item.badgeText ?? '${item.unreadCount}',
                    color: item.badgeColor,
                    mini: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Stack(
      children: [
        Icon(
          item.icon,
          size: 20,
          color: isSelected
              ? palette.navigationSelectedText
              : item.maintenanceMode
                  ? palette.tertiaryText
                  : palette.secondaryText,
        ),
        if (item.maintenanceMode)
          Positioned(
            bottom: -4,
            right: -4,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: palette.warning,
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.navigationBg,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ============================================================
/// COLLAPSE TOGGLE
/// ============================================================
class _CollapseToggle extends ConsumerWidget {
  final bool isExpanded;
  final ShellColorPalette palette;

  const _CollapseToggle({
    required this.isExpanded,
    required this.palette,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: palette.divider),
        ),
      ),
      child: isExpanded
          ? SizedBox(
              width: double.infinity,
              child: ShellNavItemContainer(
                onTap: () =>
                    ref.read(sidebarControllerProvider.notifier).collapse(),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_open_rounded,
                      size: 18,
                      color: palette.secondaryText,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Collapse',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ShellNavItemContainer(
              onTap: () =>
                  ref.read(sidebarControllerProvider.notifier).expand(),
              padding: const EdgeInsets.symmetric(vertical: 10),
              width: 72,
              child: Center(
                child: Icon(
                  Icons.menu_rounded,
                  size: 18,
                  color: palette.secondaryText,
                ),
              ),
            ),
    );
  }
}
