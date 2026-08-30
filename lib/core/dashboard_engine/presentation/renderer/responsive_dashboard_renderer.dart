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
///   - Consumes workspaceDashboardNavItemsProvider for pre-filtered,
///     workspace-aware items
///   - Uses WidgetRegistry for widget resolution
///   - Pure presentation component - no business decisions
///
/// ❌ Does NOT:
///   - Duplicate business logic
///   - Evaluate feature flags or governance rules
///   - Filter items based on context or device
///   - Hardcode module names, routes, or sections
///   - Bypass runtime providers
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/navigation/nav_item.dart';
import 'package:famhub_app/core/navigation/responsive_breakpoints.dart';
import 'package:famhub_app/core/navigation/resize_optimizer.dart';
import 'package:famhub_app/core/dashboard_engine/domain/models/dashboard_section.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/core/workspace/application/workspace_catalog_provider.dart';
import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';

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
    final dashboardItems = ref.watch(workspaceDashboardNavItemsProvider);
    final workspaceName = ref.watch(activeWorkspaceNameProvider);
    final catalogAsync = ref.watch(workspaceCatalogProvider);
    final breakpoint = ref.watch(breakpointProvider);
    final theme = Theme.of(context);

    // Wait for the workspace catalog so we never flash the empty state
    // before the active workspace type is known.
    if (catalogAsync.isLoading) {
      return SafeArea(
        child: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    if (dashboardItems.isEmpty) {
      return _buildEmptyState(theme, workspaceName);
    }

    // The first promoted module is the primary workspace experience.
    final featured = dashboardItems.first;
    final rest = dashboardItems.skip(1).toList();
    final sections = _buildSections(rest);

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
                // ── Workspace-aware dashboard header ──
                _buildHeader(workspaceName, theme),
                const SizedBox(height: 16),

                // ── Primary workspace experience ──
                _buildFeaturedModule(context, featured, theme),
                const SizedBox(height: 16),

                // ── Remaining promoted modules ──
                if (rest.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'More modules for this workspace are available '
                          'from the More menu.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
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
  /// GROUP ITEMS INTO SECTIONS
  /// ============================================================
  List<_DashboardSectionData> _buildSections(
    List<NavItem> items,
  ) {
    final sectionMap = <String, _DashboardSectionData>{};

    for (final item in items) {
      if (item.isChildModule) continue;

      final sectionKey = item.section ?? item.category ?? 'general';
      final sectionDisplayName = item.section ?? item.category ?? 'General';

      if (!sectionMap.containsKey(sectionKey)) {
        sectionMap[sectionKey] = _DashboardSectionData(
          section: DashboardSection(
            sectionKey: sectionKey,
            displayName: sectionDisplayName,
            displayOrder: item.displayOrder,
            layoutStyle: 'grid',
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

  Widget _buildHeader(String? workspaceName, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${workspaceName ?? 'Workspace'} Dashboard',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your workspace home',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// Prominent card for the primary workspace experience.
  /// Farmer → Farm Management (/farm), surfaced as the workspace entry.
  Widget _buildFeaturedModule(
      BuildContext context, NavItem item, ThemeData theme) {
    return Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: (item.isEnabled && !item.maintenanceMode)
            ? () => context.go(item.route)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.maintenanceMode
                          ? '${item.displayName}*'
                          : item.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.maintenanceMode
                          ? 'Under maintenance'
                          : 'Primary workspace experience',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String? workspaceName) {
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
                Icons.workspaces_outline,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '${workspaceName ?? 'Your'} workspace dashboard',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We\'re setting up this workspace. Explore the full module '
              'directory from the More menu.',
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
    // Use the first item's icon as the section icon (metadata from NavItem)
    final sectionIcon = section.items.isNotEmpty ? section.items.first.icon : null;
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
                if (sectionIcon != null) ...[
                  Icon(sectionIcon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
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
