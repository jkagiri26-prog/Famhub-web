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

import '../../config/shell_config.dart';
import '../../../theme/shell_theme.dart';
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
/// COMPACT BOTTOM NAV
/// ============================================================
///
/// Ultra-compact bottom navigation with no labels, only icons.
/// ============================================================
class _CompactBottomNav extends StatelessWidget {
  const _CompactBottomNav();

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(color: palette.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4, // Placeholder: simplified nav items
          (index) => IconButton(
            onPressed: () {},
            icon: Icon(
              [Icons.home_outlined, Icons.dashboard_outlined, Icons.search, Icons.person_outline][index],
              size: 20,
              color: index == 0 ? palette.primary : palette.secondaryText,
            ),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
            splashRadius: 18,
          ),
        ),
      ),
    );
  }
}

