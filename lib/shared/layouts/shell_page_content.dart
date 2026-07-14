/// ============================================================
/// SHELL PAGE CONTENT — Unified page content wrapper
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/layouts/ = reusable layout primitives
///
/// ✅ Responsibilities:
///   - Provide page structure WITHOUT creating application chrome
///   - Page title, subtitle, optional actions
///   - Page padding and scrolling
///   - Shell theme support (uses ShellThemeColors extension)
///
/// ❌ Does NOT:
///   - Create Scaffold, AppBar, or navigation widgets
///   - Reference any domain-specific code
///   - Contain business logic
///
/// The shell (UnifiedAppShellV2) owns all Scaffold/AppBar/navigation.
/// This widget renders only the content region's internals.
/// ============================================================
library;

import 'package:flutter/material.dart';

import '../../core/theme/shell_theme.dart' show ShellThemeColors;

/// ============================================================
/// SHELL PAGE CONTENT
/// ============================================================
///
/// A reusable content wrapper for feature pages.
/// Renders title, subtitle, optional action buttons, and a child
/// widget in a structured layout, with optional scrolling.
///
/// Usage:
/// ```dart
/// ShellPageContent(
///   title: 'My Farm',
///   subtitle: 'Manage your farm operations',
///   actions: [
///     IconButton(icon: Icon(Icons.add), onPressed: () {}),
///   ],
///   scrollable: true,
///   child: Column(children: [...]),
/// )
/// ```
/// ============================================================
class ShellPageContent extends StatelessWidget {
  /// Optional page title
  final String? title;

  /// Optional subtitle displayed below the title
  final String? subtitle;

  /// Optional action widgets placed to the right of the title
  final List<Widget>? actions;

  /// Whether content is scrollable (default: true)
  final bool scrollable;

  /// The main content widget
  final Widget child;

  /// Optional padding override (defaults to 16px horizontal, 8px vertical)
  final EdgeInsetsGeometry? padding;

  /// Optional title text style override
  final TextStyle? titleStyle;

  /// Optional subtitle text style override
  final TextStyle? subtitleStyle;

  const ShellPageContent({
    super.key,
    this.title,
    this.subtitle,
    this.actions,
    this.scrollable = true,
    required this.child,
    this.padding,
    this.titleStyle,
    this.subtitleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Try to resolve shell theme colors, fall back to Material theme
    final shellColors = Theme.of(context).extension<ShellThemeColors>();
    final effectiveTitleStyle = titleStyle ??
        theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: shellColors?.primaryText ?? Colors.black87,
        );
    final effectiveSubtitleStyle = subtitleStyle ??
        theme.textTheme.bodySmall?.copyWith(
          color: shellColors?.secondaryText ?? Colors.grey.shade600,
        );

    final effectivePadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0);

    // Build header if title or actions provided
    final Widget header = (title != null || actions != null)
        ? Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null || subtitle != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: effectiveTitleStyle,
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: effectiveSubtitleStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: actions!,
                  ),
                ],
              ],
            ),
          )
        : const SizedBox.shrink();

    if (scrollable) {
      return Padding(
        padding: effectivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: effectivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          child,
        ],
      ),
    );
  }
}