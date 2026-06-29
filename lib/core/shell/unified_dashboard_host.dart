import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/navigation/nav_config.dart';
import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/renderer/responsive_dashboard_renderer.dart';

/// ============================================================
/// UNIFIED DASHBOARD HOST (PRIMARY RUNTIME SHELL)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ CORRECT FLOW:
///   system.modules (backend) → ModuleService → moduleProvider
///   → navItem providers → RegistryDashboardRenderer → Dashboard UI
///
/// ✅ Responsibilities:
///   - Responsive shell layout
///   - Render dashboard regions via RegistryDashboardRenderer
///   - Show loading/error/empty states from nav_config providers
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - FULLY metadata-driven (backend registry is source of truth)
///   - FULLY registry-driven
///   - FULLY plugin-safe
///   - NO switch statements on module IDs
///   - NO hardcoded route maps
///   - NO hardcoded module names, descriptions, or icons
///   - NO conditional module metadata logic
///
/// ❌ Does NOT:
///   - Call Supabase directly
///   - Hardcode module lists
///   - Import registry into UI for business logic
///   - Perform access evaluation in widgets
///   - Place business logic in UI
///   - Bypass providers
///   - Know module IDs for icon/route/description resolution
/// ============================================================
class UnifiedDashboardHost extends ConsumerWidget {
  const UnifiedDashboardHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch dashboard items from the backend-driven provider
    // which already applies Context Engine filtering
    final dashboardItems = ref.watch(dashboardNavItemsProvider);

    // Show loading state if provider hasn't resolved yet
    final moduleAsync = ref.watch(moduleProvider);

    return moduleAsync.when(
      loading: () => const _DashboardLoadingLayout(),
      error: (error, stack) => _DashboardErrorLayout(
        message: error.toString(),
        onRetry: () => ref.invalidate(moduleProvider),
      ),
      data: (_) {
        if (dashboardItems.isEmpty) {
          return const _DashboardEmptyLayout();
        }
        return const ResponsiveDashboardRenderer();
      },
    );
  }
}

// =================================================================
// PRIVATE SUB-WIDGETS (SCOPED TO THIS FILE ONLY)
// =================================================================

/// Loading skeleton layout
class _DashboardLoadingLayout extends StatelessWidget {
  const _DashboardLoadingLayout();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 900
                      ? 3
                      : constraints.maxWidth > 600
                          ? 2
                          : 1;

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: 6,
                    itemBuilder: (context, index) {
                      return _buildSkeletonCard(theme);
                    },
                  );
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

/// Error state layout with retry action
class _DashboardErrorLayout extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardErrorLayout({
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

/// Empty state when no modules are visible
class _DashboardEmptyLayout extends StatelessWidget {
  const _DashboardEmptyLayout();

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

