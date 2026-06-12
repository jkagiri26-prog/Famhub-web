/// ============================================================
/// FEATURE DISABLED WIDGET (STANDARDIZED UX)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/states/ = reusable UX states
///
/// ✅ Standardized feature disabled state:
///   - Toggle-off icon
///   - Message about feature unavailability
///   - Optional upgrade/contact action
/// ============================================================

import 'package:flutter/material.dart';

class FeatureDisabledWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FeatureDisabledWidget({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.toggle_off_outlined,
                size: 36,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title ?? 'Feature Unavailable',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'This feature is currently not available for your account.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
