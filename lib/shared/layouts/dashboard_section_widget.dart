/// ============================================================
/// DASHBOARD SECTION WIDGET (REUSABLE DASHBOARD SECTION)
/// ============================================================
///
/// ?? LOCATION CONTEXT:
///   shared/layouts/ = reusable layout primitives
///
/// ? Responsibilities:
///   - Reusable section container for dashboard regions
///   - Consistent header with optional subtitle and trailing widget
///   - Responsive padding
///
/// ? Does NOT:
///   - Reference registry, services, or providers
///   - Contain business logic
/// ============================================================
library;

import 'package:flutter/material.dart';

class DashboardSectionWidget extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double spacing;

  const DashboardSectionWidget({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.children,
    this.padding,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // -- Section header --
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            SizedBox(height: spacing),
          ],

          // -- Section content --
          ...children,
        ],
      ),
    );
  }
}
