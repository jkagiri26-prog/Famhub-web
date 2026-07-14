/// ============================================================
/// SHELL NOT FOUND — Reusable "Page Not Found" error page
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/presentation/layouts/common/ = shared shell components
///
/// ✅ Standardized 404 / "Page Not Found" state:
///   - Warning icon (orange)
///   - "Page Not Found" title
///   - Descriptive message
///   - Shell-themed colors via ShellThemeColors
///
/// ♻️ REUSABLE BY:
///   - DynamicRouteRegistrar GoRouter errorBuilder (primary consumer)
///   - Any GoRouter configuration needing a shell-themed 404 page
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:famhub_app/core/theme/shell_theme.dart' show ShellThemeColors;

/// ============================================================
/// SHELL NOT FOUND
/// ============================================================
///
/// A reusable "Page Not Found" error page that uses shell theme
/// colors. Replaces all inline GoRouter errorBuilder
/// implementations.
/// ============================================================
class ShellNotFound extends StatelessWidget {
  /// Optional error information from GoRouter state
  final String? message;

  const ShellNotFound({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final shellColors = Theme.of(context).extension<ShellThemeColors>();
    final bgColor = shellColors?.background ?? Colors.grey.shade50;
    final textColor = shellColors?.primaryText ?? Colors.black87;
    final secondaryColor = shellColors?.secondaryText ?? Colors.grey;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Page Not Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ??
                  'The requested page could not be found.\n'
                  'Please check the URL and try again.',
              style: TextStyle(fontSize: 14, color: secondaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
