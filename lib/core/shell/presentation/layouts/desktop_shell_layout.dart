/// ============================================================
/// DESKTOP SHELL LAYOUT (1024px - 1439px)
/// ============================================================
///
/// Full sidebar, top bar, content area, optional status bar and footer.
/// Extracted from UnifiedAppShellV2 for modularity.
///
/// ✅ Performance:
///   - Each region uses ShellRegion for independent rebuild
///   - Extension slots for future extensions (AI, wallet, etc.)
///   - const constructors throughout
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../config/shell_config.dart';
import '../../../theme/shell_theme.dart';
import '../../../navigation/shell_sidebar.dart';
import '../regions/shell_app_bar.dart';
import '../regions/shell_status_bar.dart';
import '../regions/shell_floating_actions.dart';
import '../regions/shell_footer.dart';
import '../widgets/shell_region.dart';
import '../widgets/extension_slot.dart';
import '../../domain/contracts/shell_extension.dart';
import 'common/content_wrapper.dart';
import 'common/maintenance_banner.dart';

/// ============================================================
/// DESKTOP SHELL LAYOUT
/// ============================================================
///
/// Used for standard desktop widths (1024px - 1439px).
/// Features: full sidebar, top bar, status bar, FABs
/// ============================================================
class DesktopShellLayout extends StatelessWidget {
  final Widget child;
  final ShellConfig config;
  final ShellColorPalette palette;

  const DesktopShellLayout({
    super.key,
    required this.child,
    required this.config,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Maintenance Banner ──
            ShellRegion(
              name: 'maintenanceBanner',
              visible: config.showMaintenanceBanner,
              child: const MaintenanceBanner(),
            ),

            // ── Top Bar ──
            ShellRegion(
              name: 'topBar',
              visible: config.topBar.visible,
              child: ShellAppBar(config: config.topBar),
            ),

            // ── Main Content Row ──
            Expanded(
              child: Row(
                children: [
                  // ── Navigation Sidebar ──
                  ShellRegion(
                    name: 'navigation',
                    visible: config.navigation.visible,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShellSidebar(
                          showPinnedSection: config.navigation.showPinnedSection,
                          showSectionLabels: config.navigation.showSectionLabels,
                      ),
                        // ── Extension slot: navigation bottom ──
                        const ExtensionSlot(
                          slot: ShellExtensionSlot.navigationBottom,
                        ),
                      ],
                    ),
                  ),

                  // ── Vertical divider ──
                  if (config.navigation.visible)
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: palette.border,
                    ),

                  // ── Main Content Area ──
                  Expanded(
                    child: Container(
                      color: palette.background,
                      child: ContentWrapper(
                        config: config.content,
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Status Bar ──
            ShellRegion(
              name: 'statusBar',
              visible: config.statusBar.visible,
              child: ShellStatusBar(config: config.statusBar),
            ),

            // ── Footer ──
            ShellRegion(
              name: 'footer',
              visible: config.footer.visible,
              child: ShellFooter(config: config.footer),
            ),
          ],
        ),
      ),
      // ── Floating Actions ──
      floatingActionButton: config.floatingActions.enabled
          ? ShellFloatingActions(config: config.floatingActions)
          : null,
    );
  }
}

