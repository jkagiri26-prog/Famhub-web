import 'package:flutter/material.dart';

/// Consistent, premium header used by every Farm Homepage workspace tab
/// (My Farms, Crops, Livestock, Activity Logs, Reports).
///
/// Renders a gradient icon tile + title + subtitle (and optional actions) so
/// all tabs share the same visual rhythm and spacing.
class WorkspaceTabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget>? actions;

  const WorkspaceTabHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient icon tile ──
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Row(mainAxisSize: MainAxisSize.min, children: actions!),
          ],
        ],
      ),
    );
  }
}
