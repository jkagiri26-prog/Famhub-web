/// ============================================================
/// SHELL DASHBOARD ERROR — Reusable dashboard error state
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/presentation/layouts/common/ = shared shell components
///
/// ✅ Standardized dashboard error state:
///   - Cloud-off icon (identifies connection/data issue)
///   - "Unable to Load Modules" title
///   - Error detail message
///   - Retry button with invalidation callback
///   - Consistent with the original _DashboardErrorLayout appearance
///
/// ♻️ REUSABLE BY:
///   - UnifiedDashboardHost (primary consumer)
///   - Any other shell region needing a module-loading error state
/// ============================================================
library;

import 'package:flutter/material.dart';

/// ============================================================
/// SHELL DASHBOARD ERROR
/// ============================================================
///
/// A standardized error state for dashboard-level data failures.
/// Displays icon, error message, and retry action.
/// ============================================================
class ShellDashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ShellDashboardError({
    super.key,
    required this.message,
    required this.onRetry,
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Unable to Load Modules',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
