/// ============================================================
/// SHELL DASHBOARD EMPTY — Reusable dashboard empty state
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/presentation/layouts/common/ = shared shell components
///
/// ✅ Standardized dashboard empty state:
///   - Dashboard customize icon
///   - "No Modules Available" title
///   - Descriptive subtitle about unavailability
///   - Consistent with the original _DashboardEmptyLayout appearance
///
/// ♻️ REUSABLE BY:
///   - UnifiedDashboardHost (primary consumer)
///   - Any other shell region needing a dashboard-style empty state
/// ============================================================
library;

import 'package:flutter/material.dart';

/// ============================================================
/// SHELL DASHBOARD EMPTY
/// ============================================================
///
/// A standardized empty state for the dashboard region.
/// Shown when no modules are available or visible.
/// ============================================================
class ShellDashboardEmpty extends StatelessWidget {
  const ShellDashboardEmpty({super.key});

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
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.dashboard_customize_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Modules Available',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Your dashboard is ready but no modules are currently '
              'available. Please check back later or contact support.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
