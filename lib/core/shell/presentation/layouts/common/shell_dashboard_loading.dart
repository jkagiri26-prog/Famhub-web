/// ============================================================
/// SHELL DASHBOARD LOADING — Reusable dashboard loading skeleton
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/presentation/layouts/common/ = shared shell components
///
/// ✅ Standardized dashboard loading state:
///   - Header skeleton (title + subtitle placeholders)
///   - Grid of module card skeletons
///   - Responsive column count via breakpointProvider
///   - Consistent with the original _DashboardLoadingLayout appearance
///
/// ♻️ REUSABLE BY:
///   - UnifiedDashboardHost (primary consumer)
///   - Any other shell region needing a dashboard-style loading skeleton
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../navigation/resize_optimizer.dart';

/// ============================================================
/// SHELL DASHBOARD LOADING
/// ============================================================
///
/// A skeleton loading layout for the dashboard region.
/// Shows placeholder cards in a responsive grid.
/// ============================================================
class ShellDashboardLoading extends ConsumerWidget {
  final int skeletonCount;

  const ShellDashboardLoading({
    super.key,
    this.skeletonCount = 6,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final breakpointState = ref.watch(breakpointProvider);
    final crossAxisCount = breakpointState.columnCount;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header skeleton ──
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 200,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 280,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            // ── Module grid skeleton ──
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: skeletonCount,
                itemBuilder: (context, index) {
                  return _buildSkeletonCard(theme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 120,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 140,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Spacer(),
            Container(
              width: 80,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
