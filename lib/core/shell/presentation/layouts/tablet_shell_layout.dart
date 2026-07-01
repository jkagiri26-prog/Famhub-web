/// ============================================================
/// TABLET SHELL LAYOUT (600px - 1023px)
/// ============================================================
///
/// Compact top bar, navigation rail, content, optional status bar.
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
import '../widgets/shell_region.dart';
import '../widgets/extension_slot.dart';
import '../../domain/contracts/shell_extension.dart';
import 'common/content_wrapper.dart';
import 'common/maintenance_banner.dart';

/// ============================================================
/// TABLET SHELL LAYOUT
/// ============================================================
///
/// Used for tablet widths (600px - 1023px).
/// Features: compact top bar, navigation rail, status bar, FABs.
/// ============================================================
class TabletShellLayout extends StatelessWidget {
  final Widget child;
  final ShellConfig config;
  final ShellColorPalette palette;

  const TabletShellLayout({
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

            // ── Top Bar (compact) ──
            ShellRegion(
              name: 'topBar',
              visible: config.topBar.visible,
              child: ShellAppBar(config: config.topBar),
            ),

            Expanded(
              child: Row(
                children: [
                  // ── Compact Navigation Rail ──
                  ShellRegion(
                    name: 'navigation',
                    visible: config.navigation.visible,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShellSidebar(
                          showPinnedSection: config.navigation.showPinnedSection,
                          showSectionLabels: false,
                      ),
                        // ── Extension slot: navigation bottom ──
                        ExtensionSlot(
                          slot: ShellExtensionSlot.navigationBottom,
                        ),
                      ],
                    ),
                  ),

                  if (config.navigation.visible)
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: palette.border,
                    ),

                  // ── Main Content ──
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
          ],
        ),
      ),
      floatingActionButton: config.floatingActions.enabled
          ? ShellFloatingActions(config: config.floatingActions)
          : null,
    );
  }
}

