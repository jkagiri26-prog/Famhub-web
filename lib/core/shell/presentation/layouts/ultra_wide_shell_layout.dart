/// ============================================================
/// ULTRA-WIDE SHELL LAYOUT (1440px+)
/// ============================================================
///
/// Collapsible sidebar, content, and optional right secondary panel.
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
import '../../../navigation/shell_sidebar.dart';
import '../regions/shell_app_bar.dart';
import '../regions/shell_status_bar.dart';
import '../regions/shell_floating_actions.dart';
import '../regions/shell_footer.dart';
import '../regions/shell_secondary_panel.dart';
import '../widgets/shell_region.dart';
import '../widgets/extension_slot.dart';
import '../../domain/contracts/shell_extension.dart';
import 'common/content_wrapper.dart';
import 'common/maintenance_banner.dart';

/// ============================================================
/// ULTRA-WIDE SHELL LAYOUT
/// ============================================================
///
/// Used for ultra-wide screens (1440px+).
/// Features: collapsible sidebar, top bar, status bar, footer,
/// right secondary panel, FABs.
/// ============================================================
class UltraWideShellLayout extends StatelessWidget {
  final Widget child;
  final ShellConfig config;
  final ShellColorPalette palette;

  const UltraWideShellLayout({
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
                  // ── Navigation Sidebar (collapsible) ──
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
                        ExtensionSlot(
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

                  // ── Secondary Panel ──
                  if (config.secondaryPanel.visible)
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: palette.border,
                    ),
                  ShellRegion(
                    name: 'secondaryPanel',
                    visible: config.secondaryPanel.visible,
                    child: ShellSecondaryPanel(
                      config: config.secondaryPanel,
                      palette: palette,
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
      floatingActionButton: config.floatingActions.enabled
          ? ShellFloatingActions(config: config.floatingActions)
          : null,
    );
  }
}

