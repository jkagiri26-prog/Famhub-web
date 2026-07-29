/// ============================================================
/// FARM HOME PAGE — Official Hierarchy Dashboard
/// ============================================================
///
/// 🏗️ OFFICIAL HIERARCHY:
///   Farm / Entity → Field / Block → Crop or Livestock → Activity → Report
///
/// ✅ Responsibilities:
///   - Top-level tabs: Overview | My Farms | Fields/Blocks | Crops | Livestock | Activities | Reports
///   - Breadcrumb navigation: Farm > Field > Crop/Livestock > Activities > Reports
///   - Dashboard widgets receive entityId, fieldId, cropOrLivestockId as filter context
///   - Visual layout follows hierarchy order
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Shell-compliant: no Scaffold, no AppBar
///   - TabBar is rendered as page content
///   - Uses HierarchyProvider for context
///   - All widgets receive hierarchy filter context
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/navigation/resize_optimizer.dart';
import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/demo/demo_banner_widget.dart' show ExploreBanner;
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';

import 'package:famhub_app/features/farm_management/presentation/widgets/hierarchy_breadcrumb.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

import 'package:famhub_app/features/farm_management/presentation/pages/farms_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/fields_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/crops_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/livestock_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/activities_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/reports_page.dart';

/// ============================================================
/// FARM HOME PAGE — PRIMARY MODULE ENTRY POINT
/// ============================================================
class FarmHomePage extends ConsumerStatefulWidget {
  const FarmHomePage({super.key});

  @override
  ConsumerState<FarmHomePage> createState() => _FarmHomePageState();
}

class _FarmHomePageState extends ConsumerState<FarmHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _bootstrapped = false;

  /// 🏗️ Official Hierarchy Tabs
  static const _tabs = <_TabInfo>[
    _TabInfo('Overview', Icons.dashboard),
    _TabInfo('My Farms', Icons.agriculture),
    _TabInfo('Fields/Blocks', Icons.terrain),
    _TabInfo('Crops', Icons.eco),
    _TabInfo('Livestock', Icons.pets),
    _TabInfo('Activities', Icons.list_alt),
    _TabInfo('Reports', Icons.description),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _initializeModule();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeModule() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    // Load farms if not loaded
    final selectorState = ref.read(farmSelectorProvider);
    if (selectorState.farms.isEmpty && !selectorState.isLoading) {
      await ref.read(farmSelectorProvider.notifier).loadFarms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectorState = ref.watch(farmSelectorProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    final hierarchy = ref.watch(hierarchyProvider);

    return ShellPageContent(
      title: 'Farm Management',
      subtitle: hierarchy.hasEntity
          ? '${hierarchy.entity!.farmName}${hierarchy.hasField ? ' › ${hierarchy.field!.fieldName}' : ''}'
          : 'Manage your agricultural operations',
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hierarchy Breadcrumb ──
          if (hierarchy.hasEntity) const HierarchyBreadcrumb(),

          // ── Tab Bar ──
          SizedBox(
            width: double.infinity,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: _tabs
                  .map((t) => Tab(
                        text: t.label,
                        icon: Icon(t.icon, size: 18),
                      ))
                  .toList(),
              indicatorColor: Theme.of(context).colorScheme.primary,
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const Divider(height: 1),

          // ── Tab Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Overview Dashboard
                _buildOverviewTab(context, selectorState, hierarchy),

                // 2. My Farms
                const FarmsPage(),

                // 3. Fields/Blocks
                const FieldsPage(),

                // 4. Crops
                const CropsPage(),

                // 5. Livestock
                const LivestockPage(),

                // 6. Activities
                const ActivitiesPage(),

                // 7. Reports
                const ReportsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// OVERVIEW TAB — Hierarchy Dashboard
  /// ============================================================
  ///
  /// Visually displays the hierarchy in order:
  ///   1. Farm/Entity KPIs
  ///   2. Field/Block Summary
  ///   3. Crop/Livestock Summary
  ///   4. Activity Feed
  ///   5. Reports Quick Access
  ///
  /// All dashboard widgets receive entityId, fieldId, and
  /// cropOrLivestockId as filter context.
  /// ============================================================
  Widget _buildOverviewTab(
    BuildContext context,
    FarmSelectorState selectorState,
    HierarchySelectionState hierarchy,
  ) {
    if (selectorState.isLoading) {
      return const Center(child: LoadingStateWidget(useSkeleton: true));
    }

    if (selectorState.errorMessage != null) {
      return ErrorStateWidget(
        title: 'Unable to Load Farms',
        message: 'We encountered a problem loading your farm data.',
        retryLabel: 'Retry',
        onRetry: () => ref.read(farmSelectorProvider.notifier).loadFarms(),
        detailedError: selectorState.errorMessage,
      );
    }

    if (selectorState.farms.isEmpty) {
      return _buildEmptyFarmState(context);
    }

    // Render the hierarchy dashboard with registered widgets
    return _buildHierarchyDashboard(context, hierarchy);
  }

  Widget _buildEmptyFarmState(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.agriculture_rounded,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Welcome to Farm Management',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Get started by creating your first farm. '
            'Manage fields, track crops, monitor livestock, '
            'and record all your farming activities in one place.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// ============================================================
  /// HIERARCHY DASHBOARD
  /// ============================================================
  ///
  /// Renders dashboard widgets in hierarchy order:
  ///   1. Farm/Entity KPIs
  ///   2. Field/Block Summary
  ///   3. Crop/Livestock Summary
  ///   4. Activities Timeline
  ///   5. Reports Quick Access
  ///
  /// Each widget receives the current entityId, fieldId, and
  /// cropOrLivestockId as filter context.
  /// ============================================================
  Widget _buildHierarchyDashboard(
    BuildContext context,
    HierarchySelectionState hierarchy,
  ) {
    final theme = Theme.of(context);
    final breakpoint = ref.watch(breakpointProvider);
    final isMobile = breakpoint.deviceType == 'compactXs' ||
        breakpoint.deviceType == 'mobile';

    // Resolve widget descriptors from registry
    final descriptorsAsync = ref.watch(
      moduleWidgetDescriptorsProvider('farm_management'),
    );

    return descriptorsAsync.when(
      loading: () => const Center(child: LoadingStateWidget(useSkeleton: true)),
      error: (err, _) => _buildStaticHierarchyView(theme, hierarchy, isMobile),
      data: (descriptors) {
        if (descriptors.isEmpty) {
          return _buildStaticHierarchyView(theme, hierarchy, isMobile);
        }
        return _buildDynamicHierarchyView(
          theme, descriptors, hierarchy, isMobile,
        );
      },
    );
  }

  /// Build dashboard from runtime descriptors
  Widget _buildDynamicHierarchyView(
    ThemeData theme,
    List<DashboardWidgetDescriptor> descriptors,
    HierarchySelectionState hierarchy,
    bool isMobile,
  ) {
    // Resolve widgets from registry
    final widgetEntries = <_WidgetEntry>[];
    for (final desc in descriptors) {
      final builder = WidgetRegistry.resolve(desc.widgetKey);
      if (builder != null) {
        widgetEntries.add(_WidgetEntry(
          descriptor: desc,
          widget: ModuleErrorBoundary(
            moduleKey: desc.widgetKey,
            displayName: desc.displayName,
            child: _HierarchyFilterWrapper(
              entityId: hierarchy.entityId,
              fieldId: hierarchy.fieldId,
              cropOrLivestockId: hierarchy.cropOrLivestockId,
              child: builder(),
            ),
          ),
        ));
      }
    }

    // Sort by display order
    widgetEntries.sort(
      (a, b) => a.descriptor.displayOrder.compareTo(b.descriptor.displayOrder),
    );

    if (widgetEntries.isEmpty) {
      return _buildStaticHierarchyView(theme, hierarchy, isMobile);
    }

    // Render in hierarchy order sections
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hierarchy Section 1: Farm / Entity ──
          _HierarchySection(
            title: 'Farm / Entity',
            icon: Icons.agriculture,
            color: theme.colorScheme.primary,
            child: isMobile
                ? Column(
                    children: widgetEntries
                        .where((e) => _isEntityWidget(e.descriptor.widgetKey))
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DashboardCard(child: e.widget),
                            ))
                        .toList(),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: widgetEntries
                        .where((e) => _isEntityWidget(e.descriptor.widgetKey))
                        .map((e) => SizedBox(
                              width: _widgetWidth(context, isMobile),
                              child: _DashboardCard(child: e.widget),
                            ))
                        .toList(),
                  ),
          ),

          // ── Hierarchy Section 2: Field / Block ──
          if (hierarchy.hasEntity)
            _HierarchySection(
              title: 'Field / Block',
              icon: Icons.terrain,
              color: Colors.brown,
              child: _buildSectionContent(context, widgetEntries, 'field', isMobile),
            ),

          // ── Hierarchy Section 3: Crop or Livestock ──
          if (hierarchy.hasField)
            _HierarchySection(
              title: hierarchy.cropOrLivestockType == 'livestock'
                  ? 'Livestock'
                  : 'Crop',
              icon: hierarchy.cropOrLivestockType == 'livestock'
                  ? Icons.pets
                  : Icons.eco,
              color: hierarchy.cropOrLivestockType == 'livestock'
                  ? Colors.orange
                  : Colors.green,
              child: _buildSectionContent(
                  context, widgetEntries, 'crop_livestock', isMobile),
            ),

          // ── Hierarchy Section 4: Activity ──
          if (hierarchy.hasCropOrLivestock)
            _HierarchySection(
              title: 'Activities',
              icon: Icons.list_alt,
              color: Colors.blue,
              child: _buildSectionContent(
                  context, widgetEntries, 'activity', isMobile),
            ),

          // ── Hierarchy Section 5: Reports Quick Access ──
          if (hierarchy.hasCropOrLivestock)
            _HierarchySection(
              title: 'Reports',
              icon: Icons.description,
              color: Colors.purple,
              child: _buildSectionContent(
                  context, widgetEntries, 'report', isMobile),
            ),

          // If no hierarchy selection yet, show all widgets
          if (!hierarchy.hasEntity)
            ...widgetEntries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DashboardCard(child: entry.widget),
                )),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionContent(
    BuildContext context,
    List<_WidgetEntry> entries,
    String category,
    bool isMobile,
  ) {
    final filtered = entries.where((e) {
      final key = e.descriptor.widgetKey;
      switch (category) {
        case 'field':
          return key.contains('field') || key.contains('farm_summary');
        case 'crop_livestock':
          return key.contains('crop') || key.contains('livestock') ||
                 key.contains('production');
        case 'activity':
          return key.contains('activity');
        case 'report':
          return key.contains('kpi') || key.contains('stock');
        default:
          return true;
      }
    }).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    if (isMobile) {
      return Column(
        children: filtered
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DashboardCard(child: e.widget),
                ))
            .toList(),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: filtered
          .map((e) => SizedBox(
                width: _widgetWidth(context, isMobile),
                child: _DashboardCard(child: e.widget),
              ))
          .toList(),
    );
  }

  bool _isEntityWidget(String key) {
    return key.contains('farm_selector') || key.contains('farm_kpis') ||
           key.contains('farm_summary') || key.contains('farm_weather') ||
           key.contains('farm_quick_actions') || key.contains('farm_alerts');
  }

  double _widgetWidth(BuildContext context, bool isMobile) {
    if (isMobile) return double.infinity;
    final breakpoint = ref.watch(breakpointProvider);
    if (breakpoint.deviceType == 'tablet') {
      return (MediaQuery.of(context).size.width - 44) / 2;
    }
    return (MediaQuery.of(context).size.width - 56) / 3;
  }

  /// Static fallback when registry is not available
  Widget _buildStaticHierarchyView(
    ThemeData theme,
    HierarchySelectionState hierarchy,
    bool isMobile,
  ) {
    final farmWidgetKeys = <String>[
      'farm_farm_selector',
      'farm_kpis',
      'farm_summary',
      'farm_activity_timeline',
      'farm_production_summary',
      'farm_alerts',
      'farm_stock_summary',
      'farm_livestock',
      'farm_weather',
      'farm_quick_actions',
    ];

    final resolvedWidgets = <Widget>[];
    for (final key in farmWidgetKeys) {
      final builder = WidgetRegistry.resolve(key);
      if (builder != null) {
        resolvedWidgets.add(
          _HierarchyFilterWrapper(
            entityId: hierarchy.entityId,
            fieldId: hierarchy.fieldId,
            cropOrLivestockId: hierarchy.cropOrLivestockId,
            child: builder(),
          ),
        );
      }
    }

    if (resolvedWidgets.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.agriculture,
        title: 'Farm Dashboard',
        subtitle: 'Select a farm to view your dashboard.',
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Farm/Entity Section
          _HierarchySection(
            title: 'Farm / Entity',
            icon: Icons.agriculture,
            color: theme.colorScheme.primary,
            child: isMobile
                ? Column(
                    children: resolvedWidgets.take(3).map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DashboardCard(child: w),
                    )).toList(),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: resolvedWidgets.take(3).map((w) => SizedBox(
                      width: _widgetWidth(context, isMobile),
                      child: _DashboardCard(child: w),
                    )).toList(),
                  ),
          ),
          const SizedBox(height: 16),

          // All remaining widgets
          ...resolvedWidgets.skip(3).map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DashboardCard(child: w),
          )),
        ],
      ),
    );
  }
}

/// ============================================================
/// HIERARCHY FILTER WRAPPER
/// ============================================================
///
/// Wraps dashboard widgets with hierarchy filter context.
/// Each widget receives entityId, fieldId, and cropOrLivestockId.
/// ============================================================
class _HierarchyFilterWrapper extends InheritedWidget {
  final String? entityId;
  final String? fieldId;
  final String? cropOrLivestockId;

  const _HierarchyFilterWrapper({
    required this.entityId,
    required this.fieldId,
    required this.cropOrLivestockId,
    required super.child,
  });

  static _HierarchyFilterWrapper? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_HierarchyFilterWrapper>();
  }

  @override
  bool updateShouldNotify(_HierarchyFilterWrapper oldWidget) {
    return entityId != oldWidget.entityId ||
        fieldId != oldWidget.fieldId ||
        cropOrLivestockId != oldWidget.cropOrLivestockId;
  }
}

/// ============================================================
/// HIERARCHY SECTION
/// ============================================================
class _HierarchySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _HierarchySection({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(color: color.withValues(alpha: 0.2)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// ============================================================
/// DASHBOARD CARD WRAPPER
/// ============================================================
class _DashboardCard extends StatelessWidget {
  final Widget child;

  const _DashboardCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// ============================================================
/// INTERNAL DATA MODELS
/// ============================================================
class _TabInfo {
  final String label;
  final IconData icon;
  const _TabInfo(this.label, this.icon);
}

class _WidgetEntry {
  final DashboardWidgetDescriptor descriptor;
  final Widget widget;
  const _WidgetEntry({required this.descriptor, required this.widget});
}
