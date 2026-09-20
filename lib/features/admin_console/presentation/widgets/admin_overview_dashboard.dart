/// ============================================================
/// ADMIN OVERVIEW DASHBOARD
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/widgets/ = presentation
///
/// The first real screen of the Administration workspace: a platform
/// control-center overview.
///
/// ✅ Reuses the existing architecture:
///   - Authorization comes from the existing permission runtime
///     (`adminCapabilityStatusProvider` / `core.has_permission`).
///   - Layout reuses the shared dashboard primitives
///     (`DashboardSectionWidget`, `AdaptiveContentGrid`, `StatsCard`).
///   - The only live metric source is `system.modules` via `moduleProvider`.
///
/// ❌ Does NOT:
///   - Invent metrics, RPCs or tables.
///   - Hardcode dashboard statistics.
///   - Bypass authorization (no ownership / can_manage / role-name checks).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/features/admin_console/application/providers/admin_capability_provider.dart';
import 'package:famhub_app/features/admin_console/domain/permissions/permissions.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';
import 'package:famhub_app/shared/layouts/dashboard_section_widget.dart';
import 'package:famhub_app/shared/widgets/cards/stats_card_widget.dart';

class AdminOverviewDashboard extends ConsumerWidget {
  const AdminOverviewDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Gate the overview on the existing platform-overview permission.
    // No permission is inferred or bypassed client-side.
    final overviewAsync = ref.watch(
      adminCapabilityStatusProvider(AdminPermissions.platformOverview),
    );
    final overview = overviewAsync.value;
    if (overviewAsync.isLoading || overview == null || !overview.isAllowed) {
      return const SizedBox.shrink();
    }

    final modulesAsync = ref.watch(moduleProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Platform Overview ──
        const DashboardSectionWidget(
          title: 'Platform Overview',
          subtitle: 'Platform-wide status and governance summary',
          children: [
            _UnavailableCard(
              icon: Icons.insights_outlined,
              message:
                  'Platform user and entity counts are not available yet.',
            ),
          ],
        ),

        // ── 2. Platform Modules ──
        DashboardSectionWidget(
          title: 'Platform Modules',
          subtitle: 'Module activation, maintenance and management',
          children: [
            modulesAsync.when(
              data: (modules) {
                final enabled = modules.where((m) => m.isEnabled).length;
                final disabled = modules.length - enabled;
                final maintenance =
                    modules.where((m) => m.maintenanceMode).length;
                return AdaptiveContentGrid(
                  items: [
                    StatsCard(
                      title: 'Enabled modules',
                      value: '$enabled',
                      icon: Icons.toggle_on_outlined,
                    ),
                    StatsCard(
                      title: 'Disabled modules',
                      value: '$disabled',
                      icon: Icons.toggle_off_outlined,
                    ),
                    StatsCard(
                      title: 'In maintenance',
                      value: '$maintenance',
                      icon: Icons.build_outlined,
                    ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (_, __) => const _UnavailableCard(
                icon: Icons.error_outline,
                message: 'Module status is not available right now.',
              ),
            ),
            const SizedBox(height: 8),
            const _UnavailableCard(
              icon: Icons.tune,
              message:
                  'Module management opens from the Modules capability below.',
            ),
          ],
        ),

        // ── 3. Users & Access ──
        const DashboardSectionWidget(
          title: 'Users & Access',
          subtitle: 'Users, roles and permissions',
          children: [
            _UnavailableCard(
              icon: Icons.people_outline,
              message:
                  'Platform user, role and permission counts are not '
                  'available yet.',
            ),
          ],
        ),

        // ── 4. Commerce & Activity ──
        const DashboardSectionWidget(
          title: 'Commerce & Activity',
          subtitle: 'Marketplace, orders and transactions',
          children: [
            _UnavailableCard(
              icon: Icons.storefront_outlined,
              message: 'Platform-wide commerce activity is not available yet.',
            ),
          ],
        ),

        // ── 5. System Health ──
        const DashboardSectionWidget(
          title: 'System Health',
          subtitle: 'Feature flags, access rules and workflows',
          children: [
            _UnavailableCard(
              icon: Icons.monitor_heart_outlined,
              message:
                  'Feature flag, access rule and workflow status is not '
                  'available yet.',
            ),
          ],
        ),
      ],
    );
  }
}

/// Honest placeholder for a platform area that has no confirmed backend
/// source yet. Never shows fabricated numbers.
class _UnavailableCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _UnavailableCard({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
