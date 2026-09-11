import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/application/providers/admin_capability_provider.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_capability.dart';
import 'package:famhub_app/features/admin_console/presentation/widgets/admin_capability_card_widget.dart';
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
/// This is the landing page for the Admin workspace. It is rendered
/// through the existing `UnifiedDashboardHost` via `ModulePageRegistry`
/// (module key `admin_console`) — no separate dashboard engine, no
/// duplicate route.
///
/// ✅ Capability-driven:
///   - Sections are Admin capability descriptors, not hardcoded actions.
///   - Only capabilities explicitly allowed by the existing context /
///     permission runtime are rendered.
///   - Platform administration and entity administration are separate;
///     holding one never implies the other.
///   - When permission data is unavailable, a safe locked state is shown.
///
/// ❌ Does NOT:
///   - Implement management operations (foundation phase only).
///   - Grant permissions in Flutter.
///   - Show fabricated statistics or placeholder metrics.
/// ============================================================
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminDashboardAccessProvider);

    return ResponsiveWrapper(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ModuleHeaderWidget(
              title: 'Administration',
              subtitle: 'Platform and organisation administration',
              trailingIcon: Icons.admin_panel_settings_outlined,
            ),
            const SizedBox(height: 20),
            _buildBody(access),
            const SizedBox(height: 80),
          ],
        ),
      ),
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
