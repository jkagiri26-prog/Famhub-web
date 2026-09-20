import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/features/admin_console/application/providers/admin_capability_provider.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_capability.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_capability_card_widget.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_overview_dashboard.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';
import 'package:famhub_app/shared/layouts/dashboard_section_widget.dart';
import 'package:famhub_app/shared/layouts/responsive_wrappers_widget.dart';
import 'package:famhub_app/shared/widgets/headers/module_header_widget.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

/// ============================================================
/// ADMIN DASHBOARD — Workspace landing page
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/pages/ = Admin landing
///
/// The Administration workspace landing page, organised into top-level
/// internal tabs (presentation/navigation only):
///
///   Overview | Users | Entities | Modules | Access | System
///
/// ✅ Architecture:
///   - Rendered through the existing `UnifiedDashboardHost` /
///     `ModulePageRegistry` (module key `admin_console`).
///   - Overview is the existing capability-driven dashboard.
///   - Modules reuses `system.modules` via `moduleProvider`.
///   - Tabs are internal navigation; no new routes or shell.
///   - Authorization stays with the existing permission runtime.
///
/// ❌ Does NOT:
///   - Create a parallel admin architecture.
///   - Show fabricated statistics or backend data.
/// ============================================================
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminDashboardAccessProvider);

    return DefaultTabController(
      length: 6,
      child: ResponsiveWrapper(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ModuleHeaderWidget(
              title: 'Administration',
              subtitle: 'Platform and organisation administration',
              trailingIcon: Icons.admin_panel_settings_outlined,
            ),
            const SizedBox(height: 12),
            const _AdminTabBar(),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _AdminOverviewTab(access: access),
                  const _AdminPlaceholderTab(
                    icon: Icons.people_outline,
                    title: 'Users',
                    description:
                        'Platform user accounts and access.',
                    note: 'User administration is planned for a later phase.',
                  ),
                  const _AdminPlaceholderTab(
                    icon: Icons.business_outlined,
                    title: 'Entities',
                    description:
                        'Platform-wide entities, memberships and roles.',
                    note:
                        'Entity administration is planned for a later phase.',
                  ),
                  const _AdminModulesTab(),
                  const _AdminPlaceholderTab(
                    icon: Icons.verified_user_outlined,
                    title: 'Access',
                    description:
                        'Roles, permissions and module access rules.',
                    note:
                        'Access configuration is planned for a later phase.',
                  ),
                  const _AdminPlaceholderTab(
                    icon: Icons.monitor_heart_outlined,
                    title: 'System',
                    description:
                        'Feature flags, workflows and platform configuration.',
                    note:
                        'System controls are planned for a later phase.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact, horizontally scrollable tab bar (works on narrow screens
/// without wrapping).
class _AdminTabBar extends StatelessWidget {
  const _AdminTabBar();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: primary,
      labelColor: primary,
      unselectedLabelColor: Colors.grey.shade600,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      tabs: const [
        Tab(text: 'Overview'),
        Tab(text: 'Users'),
        Tab(text: 'Entities'),
        Tab(text: 'Modules'),
        Tab(text: 'Access'),
        Tab(text: 'System'),
      ],
    );
  }
}

/// ============================================================
/// OVERVIEW TAB — existing Admin Overview + capability sections
/// ============================================================
class _AdminOverviewTab extends StatelessWidget {
  final AdminDashboardAccess access;

  const _AdminOverviewTab({required this.access});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      child: _buildBody(access),
    );
  }

  Widget _buildBody(AdminDashboardAccess access) {
    if (access.isLoading) {
      return const LoadingStateWidget(
        message: 'Resolving administration access...',
      );
    }

    if (!access.isAllowed) {
      return PermissionDeniedWidget(
        title: 'Administration locked',
        message: access.reason ??
            'Administration is not available for this context.',
      );
    }

    if (!access.hasAnyCapability) {
      return const EmptyStateWidget(
        icon: Icons.verified_user_outlined,
        title: 'No administration capabilities',
        subtitle:
            'No administration capabilities are enabled for your role and '
            'organisation. Capabilities appear here once granted by the '
            'backend.',
      );
    }

    final hasPlatform = access.platformCapabilities.isNotEmpty;
    final hasEntity = access.entityCapabilities.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Admin Overview (platform control center) ──
        const AdminOverviewDashboard(),
        const SizedBox(height: 28),

        if (hasPlatform)
          _CapabilitySection(
            title: 'Platform administration',
            subtitle: 'Manage FAMHUB itself',
            capabilities: access.platformCapabilities,
          ),
        if (hasPlatform && hasEntity) const SizedBox(height: 28),
        if (hasEntity)
          _CapabilitySection(
            title: 'Organisation administration',
            subtitle: 'Manage your active organisation/entity',
            capabilities: access.entityCapabilities,
          ),
      ],
    );
  }
}

class _CapabilitySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<AdminCapability> capabilities;

  const _CapabilitySection({
    required this.title,
    required this.subtitle,
    required this.capabilities,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardSectionWidget(
      title: title,
      subtitle: subtitle,
      padding: EdgeInsets.zero,
      children: [
        AdaptiveContentGrid(
          items: [
            for (final capability in capabilities)
              AdminCapabilityCardWidget(capability: capability),
          ],
        ),
      ],
    );
  }
}

/// ============================================================
/// MODULES TAB — read-only view of the existing `system.modules`
/// ============================================================
class _AdminModulesTab extends ConsumerWidget {
  const _AdminModulesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(moduleProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      child: DashboardSectionWidget(
        title: 'Platform Modules',
        subtitle: 'Registered modules from system.modules',
        padding: EdgeInsets.zero,
        children: [
          modulesAsync.when(
            data: (modules) {
              if (modules.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.widgets_outlined,
                  title: 'No modules',
                  subtitle: 'No modules are registered yet.',
                );
              }
              return Column(
                children: [
                  for (final module in modules)
                    _AdminModuleRow(module: module),
                ],
              );
            },
            loading: () => const LoadingStateWidget(
              message: 'Loading modules...',
            ),
            error: (e, _) => ErrorStateWidget(
              title: 'Failed to load modules',
              message: 'Could not load system modules.',
              retryLabel: 'Retry',
              onRetry: () => ref.invalidate(moduleProvider),
              detailedError: e.toString(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminModuleRow extends StatelessWidget {
  final SystemModule module;

  const _AdminModuleRow({required this.module});

  @override
  Widget build(BuildContext context) {
    final maintenance = module.maintenanceMode;
    final color = maintenance
        ? Colors.orange
        : (module.isEnabled ? Colors.green : Colors.grey);
    final label = maintenance
        ? 'Maintenance'
        : (module.isEnabled ? 'Enabled' : 'Disabled');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  module.moduleKey,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// PLACEHOLDER TAB — communicates a section without fake data
/// ============================================================
class _AdminPlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String note;

  const _AdminPlaceholderTab({
    required this.icon,
    required this.title,
    required this.description,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 24, bottom: 80),
      child: EmptyStateWidget(
        icon: icon,
        title: title,
        subtitle: '$description\n\n$note',
      ),
    );
  }
}
