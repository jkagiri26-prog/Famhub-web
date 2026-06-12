/// ============================================================
/// MAINTENANCE STATE WIDGET (STANDARDIZED UX)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/states/ = reusable UX states
///
/// ✅ Standardized maintenance state:
///   - Build/settings icon
///   - Message about maintenance
///   - Optional estimated completion info
/// ============================================================

import 'package:flutter/material.dart';

class MaintenanceStateWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final String? estimatedCompletion;

  const MaintenanceStateWidget({
    super.key,
    this.title,
    this.message,
    this.estimatedCompletion,
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
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.construction_rounded,
                size: 36,
                color: Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title ?? 'Under Maintenance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'This feature is currently undergoing maintenance. Please check back later.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (estimatedCompletion != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Estimated completion: $estimatedCompletion',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
