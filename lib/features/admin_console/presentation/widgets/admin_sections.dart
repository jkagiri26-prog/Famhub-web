/// ============================================================
/// ADMIN DOMAIN SECTIONS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/presentation/widgets/ = presentation
///
/// One widget per top-level Administration domain. Each uses the reusable
/// `AdminSectionScaffold` so sub-tab navigation is consistent.
///
/// Real data sources (already existing + confirmed):
///   - Users > Workspaces  → `system.workspaces` (workspaceCatalogProvider)
///   - Modules > All/Enabled/Maintenance → `system.modules` (moduleProvider)
///
/// Everything else is an honest `AdminPlaceholder` — no fabricated data and
/// no invented RPCs/tables.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_catalog_provider.dart';
import 'package:famhub_app/core/workspace/domain/workspace_catalog_item.dart';
import 'package:famhub_app/shared/layouts/dashboard_section_widget.dart';
import 'package:famhub_app/shared/widgets/states/states.dart';

import 'admin_all_users_view.dart';
import 'admin_pending_users_view.dart';
import 'admin_section.dart';
import 'admin_user_activity_view.dart';

// ============================================================
// USERS
// ============================================================

class AdminUsersSection extends StatelessWidget {
  const AdminUsersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminSectionScaffold(
      title: 'Users',
      subtitle: 'Platform user accounts and access',
      tabs: [
        'All Users',
        'Pending / Onboarding',
        'User Activity',
        'Workspaces',
        'Memberships',
      ],
      children: [
        AdminAllUsersView(),
        AdminPendingUsersView(),
        AdminUserActivityView(),
        _AdminWorkspaceList(),
        AdminPlaceholder(
          icon: Icons.groups_outlined,
          title: 'Memberships',
          message: 'Platform-wide membership listing is not available yet.',
        ),
      ],
    );
  }
}

/// Real data: the registered workspace catalog (`system.workspaces`).
class _AdminWorkspaceList extends ConsumerWidget {
  const _AdminWorkspaceList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(workspaceCatalogProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      child: DashboardSectionWidget(
        title: 'Workspace catalog',
        subtitle: 'Registered workspaces from system.workspaces',
        padding: EdgeInsets.zero,
        children: [
          catalogAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.workspaces_outline,
                  title: 'No workspaces',
                  subtitle: 'No workspaces are registered yet.',
                );
              }
              return Column(
                children: [
                  for (final item in items) _AdminWorkspaceRow(item: item),
                ],
              );
            },
            loading: () => const LoadingStateWidget(
              message: 'Loading workspaces...',
            ),
            error: (e, _) => ErrorStateWidget(
              title: 'Failed to load workspaces',
              message: 'Could not load the workspace catalog.',
              retryLabel: 'Retry',
              onRetry: () => ref.invalidate(workspaceCatalogProvider),
              detailedError: e.toString(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminWorkspaceRow extends StatelessWidget {
  final WorkspaceCatalogItem item;

  const _AdminWorkspaceRow({required this.item});

  @override
  Widget build(BuildContext context) {
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
                  item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.category != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.category!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ENTITIES
// ============================================================

class AdminEntitiesSection extends StatelessWidget {
  const AdminEntitiesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminSectionScaffold(
      title: 'Entities',
      subtitle: 'Platform-wide entities, memberships and roles',
      tabs: [
        'All Entities',
        'Entity Types',
        'Members & Roles',
        'Entity Activity',
      ],
      children: [
        AdminPlaceholder(
          icon: Icons.business_outlined,
          title: 'All Entities',
          message:
              'Platform-wide entity listing is not available yet. It will '
              'appear once the admin entity directory backend is confirmed.',
        ),
        AdminPlaceholder(
          icon: Icons.category_outlined,
          title: 'Entity Types',
          message: 'Entity type breakdown is not available yet.',
        ),
        AdminPlaceholder(
          icon: Icons.badge_outlined,
          title: 'Members & Roles',
          message:
              'Platform-wide memberships and role assignments are not '
              'available yet.',
        ),
        AdminPlaceholder(
          icon: Icons.timeline,
          title: 'Entity Activity',
          message: 'Entity activity data is not available yet.',
        ),
      ],
    );
  }
}

// ============================================================
// MODULES
// ============================================================

enum _ModuleFilter { all, enabled, maintenance }

class AdminModulesSection extends StatelessWidget {
  const AdminModulesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminSectionScaffold(
      title: 'Modules',
      subtitle: 'System modules, activation and governance',
      tabs: [
        'All Modules',
        'Enabled',
        'Access Rules',
        'Feature Flags',
        'Maintenance',
      ],
      children: [
        _AdminModuleList(
          filter: _ModuleFilter.all,
          title: 'All modules',
          subtitle: 'Registered modules from system.modules',
        ),
        _AdminModuleList(
          filter: _ModuleFilter.enabled,
          title: 'Enabled modules',
          subtitle: 'Modules currently enabled',
        ),
        AdminPlaceholder(
          icon: Icons.lock_outline,
          title: 'Access Rules',
          message: 'Module access rules are not available yet.',
        ),
        AdminPlaceholder(
          icon: Icons.bolt_outlined,
          title: 'Feature Flags',
          message: 'Feature flags are not available yet.',
        ),
        _AdminModuleList(
          filter: _ModuleFilter.maintenance,
          title: 'Modules in maintenance',
          subtitle: 'Modules currently in maintenance mode',
        ),
      ],
    );
  }
}

/// Real data: the module registry (`system.modules`).
class _AdminModuleList extends ConsumerWidget {
  final _ModuleFilter filter;
  final String title;
  final String subtitle;

  const _AdminModuleList({
    required this.filter,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(moduleProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      child: DashboardSectionWidget(
        title: title,
        subtitle: subtitle,
        padding: EdgeInsets.zero,
        children: [
          modulesAsync.when(
            data: (modules) {
              final filtered = switch (filter) {
                _ModuleFilter.all => modules,
                _ModuleFilter.enabled =>
                  modules.where((m) => m.isEnabled).toList(),
                _ModuleFilter.maintenance =>
                  modules.where((m) => m.maintenanceMode).toList(),
              };
              if (filtered.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.widgets_outlined,
                  title: 'No modules',
                  subtitle: 'No modules match this view.',
                );
              }
              return Column(
                children: [
                  for (final module in filtered)
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

// ============================================================
// ACCESS
// ============================================================

class AdminAccessSection extends StatelessWidget {
  const AdminAccessSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminSectionScaffold(
      title: 'Access',
      subtitle: 'Roles, permissions and access rules',
      tabs: [
        'Roles',
        'Permissions',
        'Capabilities',
        'Module Access',
        'Entity Access',
      ],
      children: [
        AdminPlaceholder(
          icon: Icons.verified_user_outlined,
          title: 'Roles',
          message: 'Platform role management is not available yet.',
        ),
        AdminPlaceholder(
          icon: Icons.key_outlined,
          title: 'Permissions',
          message: 'Permission catalogue management is not available yet.',
        ),
        AdminPlaceholder(
          icon: Icons.workspace_premium_outlined,
          title: 'Capabilities',
          message: 'Capability configuration is not available yet.',
        ),
        AdminPlaceholder(
          icon: Icons.rule_outlined,
          title: 'Module Access',
          message: 'Module access rules are not available yet.',
        ),
        AdminPlaceholder(
          icon: Icons.domain_outlined,
          title: 'Entity Access',
          message: 'Entity access rules are not available yet.',
        ),
      ],
    );
  }
}

// ============================================================
// SYSTEM
// ============================================================

class AdminSystemSection extends StatelessWidget {
  const AdminSystemSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminSectionScaffold(
      title: 'System',
      subtitle: 'Platform health, workflows and configuration',
      tabs: [
        'System Health',
        'Workflows',
        'Subscriptions / Billing',
        'Configuration',
        'Audit / Events',
      ],
      children: [
        AdminPlaceholder(
          icon: Icons.monitor_heart_outlined,
          title: 'System Health',
          message:
              'Platform health metrics are not available yet. Module '
              'maintenance status is visible under Modules → Maintenance.',
        ),
        AdminPlaceholder(
          icon: Icons.account_tree_outlined,
          title: 'Workflows',
          message: 'Workflow management is not available yet.',
        ),
        AdminPlaceholder(
          icon: Icons.receipt_long_outlined,
          title: 'Subscriptions / Billing',
          message: 'Subscription and billing management is not available yet.',
        ),
        AdminPlaceholder(
          icon: Icons.settings_outlined,
          title: 'Configuration',
          message: 'Platform configuration is not available yet.',
        ),
        AdminPlaceholder(
          icon: Icons.history_outlined,
          title: 'Audit / Events',
          message: 'Audit and event logs are not available yet.',
        ),
      ],
    );
  }
}
