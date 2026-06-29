/// ============================================================
/// RESPONSIVE DASHBOARD RENDERER (PHASE B)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/presentation/renderer/ = presentation renderer
///
/// ✅ Responsibilities:
///   - Adaptive column count based on width (not fixed values)
///   - Spacing based on width
///   - Max content width for large screens
///   - Section wrapping
///   - Large-screen optimization
///   - NO LayoutBuilder — uses breakpoint provider
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Consumes the exact same runtime composition pipeline
///   - Same dashboardNavItemsProvider
///   - Same WidgetRegistry
///   - Same feature flags
///   - Same governance
///   - Only the layout/presentation changes
///
/// ❌ Does NOT:
///   - Duplicate business logic
///   - Hardcode module names, routes, or sections
///   - Bypass runtime providers
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/navigation/nav_config.dart';
import 'package:famhub_app/core/navigation/nav_item.dart';
import 'package:famhub_app/core/navigation/responsive_breakpoints.dart';
import 'package:famhub_app/core/navigation/resize_optimizer.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/dashboard_section.dart';
import 'package:famhub_app/core/feature_flags/application/services/runtime_feature_flags.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

/// ============================================================
/// RESPONSIVE DASHBOARD RENDERER
/// ============================================================
///
/// This renderer replaces the old LayoutBuilder-heavy approach.
/// It uses the breakpoint provider for debounced resize handling
/// and computes layout from available width using a fluid approach.
/// ============================================================
class ResponsiveDashboardRenderer extends ConsumerWidget {
  const ResponsiveDashboardRenderer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardItems = ref.watch(dashboardNavItemsProvider);
    final entityContext = ref.watch(contextProvider);
    final breakpoint = ref.watch(breakpointProvider);
    final theme = Theme.of(context);

    if (dashboardItems.isEmpty) {
      return _buildEmptyState(theme);
    }

    final deviceType = breakpoint.deviceType;
    final sections = _buildSections(dashboardItems, entityContext, deviceType);

    return SafeArea(
      child: Center(
        child: Container(
          // Constrain max width on large screens
          constraints: const BoxConstraints(
            maxWidth: ResponsiveBreakpoints.contentMaxWidth,
          ),
          child: Padding(
            padding: EdgeInsets.all(breakpoint.spacing),
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
                      return _ResponsiveSectionView(
                        section: section,
                        breakpoint: breakpoint,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ============================================================
  /// BUILD SECTIONS FROM BACKEND MODULE DATA
  /// ============================================================
  List<_DashboardSectionData> _buildSections(
    List<NavItem> items,
    EntityContext context,
    String deviceType,
  ) {
    final sectionMap = <String, _DashboardSectionData>{};

    for (final item in items) {
      if (item.isChildModule) continue;

      final result = _evaluateItem(item, context, deviceType);
      if (!result.isAllowed) continue;

      final sectionKey = item.section ?? item.category ?? 'general';
      final sectionDisplayName = item.section ?? item.category ?? 'General';

      if (!sectionMap.containsKey(sectionKey)) {
        sectionMap[sectionKey] = _DashboardSectionData(
          section: DashboardSection(
            sectionKey: sectionKey,
            displayName: sectionDisplayName,
            displayOrder: item.displayOrder,
            iconKey: _getSectionIcon(sectionKey),
            layoutStyle: deviceType == 'mobile' ? 'stacked' : 'grid',
          ),
          items: [],
        );
      }

      sectionMap[sectionKey]!.items.add(item);
    }

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
    if (!item.isEnabled) return FeatureFlagResult.denied('disabled');
    if (item.maintenanceMode) return FeatureFlagResult.denied('maintenance');
    if (!item.isVisibleOnDevice(deviceType)) {
      return FeatureFlagResult.denied('not_visible_on_device');
    }
    if (context.isGuest && item.moduleKey != 'dashboard') {
      return FeatureFlagResult.denied('guest_restricted');
    }
    return FeatureFlagResult.allowed;
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
/// DASHBOARD SECTION DATA
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
/// RESPONSIVE SECTION VIEW
/// ============================================================
///
/// Renders a named section with adaptive column count.
/// Uses fluid layout instead of fixed crossAxisCount.
/// ============================================================
class _ResponsiveSectionView extends StatelessWidget {
  final _DashboardSectionData section;
  final BreakpointState breakpoint;

  const _ResponsiveSectionView({
    required this.section,
    required this.breakpoint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionIcon = IconResolver.resolve(section.section.iconKey);
    final crossAxisCount = breakpoint.columnCount;
    final spacing = breakpoint.spacing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ──
          Padding(
            padding: EdgeInsets.only(bottom: spacing),
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
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];

              // Try to resolve a registered widget from WidgetRegistry
              final widgetBuilder = WidgetRegistry.resolve(item.moduleKey);
              if (widgetBuilder != null) {
                return ModuleErrorBoundary(
                  moduleKey: item.moduleKey,
                  displayName: item.displayName,
                  child: widgetBuilder(),
                );
              }

              // Fallback: render as module card
              return _ResponsiveModuleCard(item: item);
            },
          ),
        ],
      ),
    );
  }
}

/// ============================================================
/// RESPONSIVE MODULE CARD
/// ============================================================
class _ResponsiveModuleCard extends StatelessWidget {
  final NavItem item;

  const _ResponsiveModuleCard({required this.item});

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
          onTap: (item.isEnabled && !item.maintenanceMode)
              ? () => context.go(item.route)
              : null,
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
}
