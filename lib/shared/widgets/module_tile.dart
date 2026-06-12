import 'package:flutter/material.dart';

/// ============================================================
/// MODULE TILE (REUSABLE MODULE LAUNCHER CARD)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/ = reusable presentation layer
///
/// ✅ Responsibilities:
///   - Reusable module launcher card
///   - Icon/title/description display
///   - Responsive behavior
///   - Dashboard navigation entry
///
/// ❌ Does NOT:
///   - Reference registry, services, or providers
///   - Contain business logic
///   - Perform access evaluation
///   - Import Supabase
/// ============================================================
class ModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onTap;
  final double? height;

  const ModuleTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onTap,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon container ──
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                // ── Title ──
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // ── Description ──
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 8),
                  // ── Action indicator ──
                  Row(
                    children: [
                      Text(
                        actionLabel!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
