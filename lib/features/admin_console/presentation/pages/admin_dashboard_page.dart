import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/application/providers/admin_capability_provider.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_capability.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_capability_card_widget.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_overview_dashboard.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_section.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_sections.dart';
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
/// domains, each with its own internal sub-tabs:
///
///   Overview | Users | Entities | Modules | Access | System
///
/// ✅ Architecture:
///   - Rendered through the existing `UnifiedDashboardHost` /
///     `ModulePageRegistry` (module key `admin_console`).
///   - Overview is the existing capability-driven dashboard.
///   - Sub-tabs reuse `AdminSectionScaffold` (single navigation pattern).
///   - Authorization stays with the existing permission runtime.
///
/// ❌ Does NOT:
///   - Create a parallel admin architecture.
///   - Show fabricated statistics or backend data.
/// ============================================================
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  static const List<String> _topTabs = [
    'Overview',
    'Users',
    'Entities',
    'Modules',
    'Access',
    'System',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminDashboardAccessProvider);

    return DefaultTabController(
      length: _topTabs.length,
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
            const AdminSubTabBar(tabs: _topTabs),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _AdminOverviewTab(access: access),
                  const AdminUsersSection(),
                  const AdminEntitiesSection(),
                  const AdminModulesSection(),
                  const AdminAccessSection(),
                  const AdminSystemSection(),
                ],
              ),
            ),
          ],
        ),
      ),
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
