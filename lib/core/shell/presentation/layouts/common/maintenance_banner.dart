/// ============================================================
/// MAINTENANCE BANNER
/// ============================================================
///
/// Shows at the top of the shell when modules are in maintenance mode.
/// Shared across all shell layouts.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../../../../theme/shell_theme.dart';

/// ============================================================
/// MAINTENANCE BANNER
/// ============================================================
class MaintenanceBanner extends StatelessWidget {
  const MaintenanceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<ShellThemeColors>()?.palette ??
        ShellTheme.defaultLight;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: palette.warningBg,
      child: Row(
        children: [
          Icon(
            Icons.engineering_outlined,
            size: 16,
            color: palette.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Some services are under maintenance and may be temporarily unavailable.',
              style: TextStyle(
                fontSize: 12,
                color: palette.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
