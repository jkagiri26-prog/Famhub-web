/// ============================================================
/// MOBILE SHELL LAYOUT (<600px)
/// ============================================================
///
/// Bottom navigation bar, full-screen content, minimal top bar.
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
import '../../../navigation/shell_bottom_nav.dart';
import '../regions/shell_app_bar.dart';
import '../regions/shell_floating_actions.dart';
import '../widgets/shell_region.dart';
import '../widgets/extension_slot.dart';
import '../../domain/contracts/shell_extension.dart';
import 'common/maintenance_banner.dart';

/// ============================================================
/// MOBILE SHELL LAYOUT
/// ============================================================
///
/// Used for phone widths (<600px).
/// Features: optional minimal top bar, bottom navigation, FABs.
/// ============================================================
class MobileShellLayout extends StatelessWidget {
  final Widget child;
  final ShellConfig config;
  final ShellColorPalette palette;

  const MobileShellLayout({
    super.key,
    required this.child,
    required this.config,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.background,
      appBar: config.topBar.visible
          ? PreferredSize(
              preferredSize: Size.fromHeight(config.topBar.height),
              child: ShellAppBar(config: config.topBar),
            )
          : null,
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
          ? const ShellBottomNav()
          : null,
      floatingActionButton: config.floatingActions.enabled
          ? ShellFloatingActions(config: config.floatingActions)
          : null,
    );
  }
}

