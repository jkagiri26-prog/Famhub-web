/// ============================================================
/// SHELL SYSTEM DOWN — Reusable "System maintenance" page
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/presentation/layouts/common/ = shared shell components
///
/// ✅ Standardized system-down / maintenance mode state:
///   - Cloud-off warning icon
///   - "System maintenance in progress" title
///   - "Please check back later." message
///   - Shell-themed colors via ShellThemeColors
///
/// ♻️ REUSABLE BY:
///   - UnifiedAppShellV2 (primary consumer)
///   - Any shell consumer needing a system-down gate
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:famhub_app/core/theme/shell_theme.dart' show ShellThemeColors;

/// ============================================================
/// SHELL SYSTEM DOWN
/// ============================================================
///
/// A reusable system maintenance / system-down page that uses
/// shell theme colors. Replaces all inline maintenance UIs.
/// ============================================================
class ShellSystemDown extends StatelessWidget {
  const ShellSystemDown({super.key});

  @override
  Widget build(BuildContext context) {
    final shellColors = Theme.of(context).extension<ShellThemeColors>();
    final bgColor = shellColors?.background ?? Colors.grey.shade50;
    final primaryTextColor = shellColors?.primaryText ?? Colors.black87;
    final secondaryTextColor = shellColors?.secondaryText ?? Colors.grey;
    final warningColor = shellColors?.warning ?? Colors.orange;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: warningColor),
            const SizedBox(height: 16),
            Text(
              'System maintenance in progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check back later.',
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
