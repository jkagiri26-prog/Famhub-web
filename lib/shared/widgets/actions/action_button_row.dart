/// ============================================================
/// ACTION BUTTON ROW (REUSABLE ACTION BUTTONS)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/actions/ = reusable action widgets
///
/// ✅ Responsibilities:
///   - Consistent action button layout
///   - Primary/secondary/tertiary button variants
///   - Responsive horizontal layout
/// ============================================================

import 'package:flutter/material.dart';

class ActionButtonRow extends StatelessWidget {
  final List<ActionButtonItem> actions;
  final MainAxisAlignment alignment;

  const ActionButtonRow({
    super.key,
    required this.actions,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 400) {
          return Row(
            mainAxisAlignment: alignment,
            children: actions.map((action) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: action.build(context),
              );
            }).toList(),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: actions.map((action) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SizedBox(
                width: double.infinity,
                child: action.build(context),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class ActionButtonItem {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ActionButtonVariant variant;

  const ActionButtonItem({
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = ActionButtonVariant.primary,
  });

  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (variant) {
      case ActionButtonVariant.primary:
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

      case ActionButtonVariant.secondary:
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

      case ActionButtonVariant.tertiary:
        return TextButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
          label: Text(label),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        );
    }
  }
}

enum ActionButtonVariant { primary, secondary, tertiary }
