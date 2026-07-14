/// ============================================================
/// SHELL LOADING — Reusable generic shell loading state
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/presentation/layouts/common/ = shared shell components
///
/// ✅ Standardized shell-level loading state:
///   - Optional custom message (default: "Loading...")
///   - Optional custom indicator (default: CircularProgressIndicator)
///   - Shell-themed colors via ShellThemeColors
///
/// ♻️ REUSABLE BY:
///   - Any shell consumer needing a generic loading indicator
///     without importing Flutter Material directly
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:famhub_app/core/theme/shell_theme.dart' show ShellThemeColors;

/// ============================================================
/// SHELL LOADING
/// ============================================================
///
/// A reusable generic shell-level loading state widget.
///
/// Unlike [ShellDashboardLoading] (which renders a dashboard-specific
/// skeleton grid), this widget is a simple centered loading indicator
/// suitable for full-page or region-level loading states.
///
/// Features:
/// - Default "Loading..." message with [CircularProgressIndicator]
/// - Fully customisable [message] and [indicator]
/// - Shell-themed via [ShellThemeColors]
/// - Const-friendly constructor
/// ============================================================
class ShellLoading extends StatelessWidget {
  /// Optional loading message displayed below the indicator.
  ///
  /// Defaults to "Loading..." if not provided.
  final String? message;

  /// Optional custom progress indicator widget.
  ///
  /// Defaults to [CircularProgressIndicator] if not provided.
  final Widget? indicator;

  const ShellLoading({
    super.key,
    this.message,
    this.indicator,
  });

  @override
  Widget build(BuildContext context) {
    final shellColors = Theme.of(context).extension<ShellThemeColors>();
    final bgColor = shellColors?.background ?? Colors.grey.shade50;
    final textColor = shellColors?.primaryText ?? Colors.black87;
    final indicatorColor = shellColors?.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            indicator ??
                CircularProgressIndicator(
                  color: indicatorColor,
                ),
            const SizedBox(height: 16),
            Text(
              message ?? 'Loading...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
