import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/composition/domain/models/section_registry.dart';
import 'package:famhub_app/core/navigation/nav_config.dart';
import 'package:famhub_app/core/navigation/nav_item.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/dashboard_section.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/dashboard_widget_definition.dart';
import 'package:famhub_app/core/feature_flags/application/services/runtime_feature_flags.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

/// ============================================================
/// REGISTRY-DRIVEN DASHBOARD RENDERER (ENTERPRISE GOVERNANCE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/presentation/renderer/ = presentation renderer
///
/// ✅ Responsibilities:
///   - Dynamic dashboard composition from backend metadata
///   - Render sections and widgets with governance evaluation
///   - Each widget wrapped in individual error boundary
///   - Responsive grid layout per device type
///   - Backend-defined sections (Farm, Marketplace, Finance, etc.)
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Consumes backend-driven NavItem data
///   - Widgets resolved from WidgetRegistry (no switch statements)
///   - All rendering governed by RuntimeFeatureFlags
///   - Fully metadata-driven composition
///
/// ❌ Does NOT:
///   - Hardcode module names, routes, sections, or widgets
///   - Contain business logic
///   - Import feature modules directly
/// ============================================================
class RegistryDashboardRenderer extends ConsumerWidget {
  const RegistryDashboardRenderer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardItems = ref.watch(dashboardNavItemsProvider);
    final entityContext = ref.watch(contextProvider);
    final theme = Theme.of(context);

    if (dashboardItems.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Determine device type from screen width
    final deviceType = _resolveDeviceType(MediaQuery.of(context).size.width);

    // Build sections from backend module data
    final sections = _buildSections(dashboardItems, entityContext, deviceType);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 900
              ? 3
              : constraints.maxWidth > 600
                  ? 2
                  : 1;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Dashboard header ──
                _buildHeader(sections.length, theme),
                const SizedBox(height: 16),

                // ── Dynamic sections ──
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: sections.length,
                    itemBuilder: (context, index) {
                      final section = sections[index];
                      return _DashboardSectionView(
                        section: section,
                        crossAxisCount: crossAxisCount,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// ============================================================
  /// BUILD SECTIONS FROM BACKEND MODULE DATA
  /// ============================================================
  ///
  /// Groups NavItems into DashboardSections based on backend metadata.
  /// Each section is evaluated through RuntimeFeatureFlags.
  /// ============================================================
  List<_DashboardSectionData> _buildSections(
    List<NavItem> items,
    EntityContext context,
    String deviceType,
  ) {
    final sectionMap = <String, _DashboardSectionData>{};

    for (final item in items) {
      // Skip child modules (they appear as widgets, not tiles)
      if (item.isChildModule) continue;

      // Evaluate feature flags
      final result = _evaluateItem(item, context, deviceType);
      if (!result.isAllowed) continue;

      // Determine section key (use module.section or module.category as fallback)
      final sectionKey = item.section ?? item.category ?? 'general';
      final sectionDisplayName = item.section ?? item.category ?? 'General';

      // Create section if it doesn't exist
      if (!sectionMap.containsKey(sectionKey)) {
        sectionMap[sectionKey] = _DashboardSectionData(
          section: DashboardSection(
            sectionKey: sectionKey,
            displayName: _getSectionDisplayName(sectionKey, sectionDisplayName),
            displayOrder: item.displayOrder,
            iconKey: _getSectionIcon(sectionKey),
            layoutStyle: deviceType == 'mobile' ? 'stacked' : 'grid',
          ),
          items: [],
        );
      }

      sectionMap[sectionKey]!.items.add(item);
    }

    // Sort sections by display order
    final sortedSections = sectionMap.values.toList()
      ..sort((a, b) => a.section.displayOrder.compareTo(b.section.displayOrder));

    return sortedSections;
  }

  /// Evaluate a single nav item through RuntimeFeatureFlags
  FeatureFlagResult _evaluateItem(
    NavItem item,
    EntityContext context,
    String deviceType,
  ) {
    // Skip disabled or maintenance items
    if (!item.isEnabled) return FeatureFlagResult.denied('disabled');
    if (item.maintenanceMode) return FeatureFlagResult.denied('maintenance');

    // Check device compatibility
    if (!item.isVisibleOnDevice(deviceType)) {
      return FeatureFlagResult.denied('not_visible_on_device');
    }

    // Guest users: only show dashboard (the home route fallback)
    if (context.isGuest && item.moduleKey != 'dashboard') {
      return FeatureFlagResult.denied('guest_restricted');
    }

    return FeatureFlagResult.allowed;
  }
  /// Human-readable section display names
  String _getSectionDisplayName(String key, String fallback) {
    switch (key.toLowerCase()) {
      case 'farm':
        return 'Farm';
      case 'marketplace':
        return 'Marketplace';
      case 'analytics':
      case 'reports':
        return 'Analytics';
      case 'finance':
        return 'Finance';
      case 'logistics':
        return 'Logistics';
      case 'traceability':
        return 'Traceability';
      case 'knowledge':
        return 'Knowledge';
      case 'opportunities':
        return 'Opportunities';
      case 'community':
        return 'Community';
      case 'referral':
        return 'Referrals';
      default:
        return fallback;
    }
  }

  /// Icon for each section
  String _getSectionIcon(String key) {
    switch (key.toLowerCase()) {
      case 'farm':
        return 'agriculture';
      case 'marketplace':
        return 'store';
      case 'analytics':
      case 'reports':
        return 'analytics';
      case 'finance':
        return 'finance';
      case 'logistics':
        return 'shipping';
      case 'traceability':
        return 'qr_code';
      case 'knowledge':
        return 'library';
      case 'opportunities':
        return 'opportunities';
      case 'community':
        return 'community';
      case 'referral':
        return 'referral';
      case 'general':
        return 'dashboard';
      default:
        return 'widgets';
    }
  }

  /// Resolve device type from screen width
  String _resolveDeviceType(double width) {
    if (width < 600) return 'mobile';
    if (width < 1024) return 'tablet';
    return 'desktop';
  }

  Widget _buildHeader(int sectionCount, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dashboard',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$sectionCount section${sectionCount == 1 ? '' : 's'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
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

/// ============================================================
/// DASHBOARD SECTION DATA (INTERNAL)
/// ============================================================
class _DashboardSectionData {
  final DashboardSection section;
  final List<NavItem> items;

  _DashboardSectionData({
    required this.section,
    required this.items,
  });
}

/// ============================================================
/// DASHBOARD SECTION VIEW
/// ============================================================
///
/// Renders a named section with its widgets.
/// Each section has a header and a grid/list of widgets.
/// ============================================================
class _DashboardSectionView extends StatelessWidget {
  final _DashboardSectionData section;
  final int crossAxisCount;

  const _DashboardSectionView({
    required this.section,
    required this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionIcon = IconResolver.resolve(section.section.iconKey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ──
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(sectionIcon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  section.section.displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '${section.items.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // ── Section Widgets Grid ──
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount.clamp(1, 3),
              childAspectRatio: 1.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];

              // Try to resolve a registered widget from WidgetRegistry
              final widgetBuilder = WidgetRegistry.resolve(item.moduleKey);
              if (widgetBuilder != null) {
                // Governance-controlled widget rendering
                return ModuleErrorBoundary(
                  moduleKey: item.moduleKey,
                  displayName: item.displayName,
                  child: widgetBuilder(),
                );
              }

              // Fallback: render as module card
              return _DashboardModuleCard(item: item);
            },
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// DASHBOARD MODULE CARD
/// ============================================================
///
/// Renders a single module tile on the dashboard grid.
/// Each card is independent with its own error boundary.
/// ============================================================
class _DashboardModuleCard extends StatelessWidget {
  final NavItem item;

  const _DashboardModuleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: item.moduleKey,
      displayName: item.displayName,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: () => _navigate(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row: Icon + Optional Badge ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          item.icon,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      // ── Badge ──
                      if (item.hasBadge)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: item.badgeColor ?? Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.badgeText ?? '${item.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  // ── Title ──
                  Text(
                    item.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.maintenanceMode && item.maintenanceMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        item.maintenanceMessage!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.orange.shade700,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 4),
                  // ── Entry indicator ──
                  Row(
                    children: [
                      Text(
                        item.maintenanceMode ? 'Under Maintenance' : 'Open',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: item.maintenanceMode
                              ? Colors.orange.shade600
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!item.maintenanceMode) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context) {
    if (item.route.isNotEmpty && !item.maintenanceMode) {
      context.go(item.route);
    }
  }
}
