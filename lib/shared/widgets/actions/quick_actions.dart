/// ============================================================
/// QUICK ACTIONS (REUSABLE ACTION SHEET)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/actions/ = reusable action widgets
///
/// ✅ Responsibilities:
///   - Consistent quick action buttons
///   - Horizontal scrollable action chips
///   - Reusable across all modules
///
/// ❌ Does NOT:
///   - Contain feature-specific logic
///   - Reference registries
/// ============================================================

import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  final List<QuickActionItem> items;
  const QuickActions({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return ActionChip(
            avatar: item.icon != null
                ? Icon(item.icon, size: 16)
                : null,
            label: Text(
              item.label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: item.onPressed,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }
}

class QuickActionItem {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const QuickActionItem({
    required this.label,
    this.icon,
    this.onPressed,
  });
}
