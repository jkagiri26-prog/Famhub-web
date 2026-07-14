import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/navigation/resize_optimizer.dart';
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';

/// ============================================================
/// FARM MANAGEMENT PAGE (PRIMARY MODULE PAGE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/presentation/pages/ = page layer
///
/// ✅ Responsibilities:
///   - Primary module page for farm management
///   - Renders all dashboard widgets registered for the farm_management
///     module via ModuleRuntimeDescriptor → WidgetRegistry
///   - Follows same page pattern as Marketplace, Analytics, etc.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Uses providers (never direct Supabase calls)
///   - Widgets resolved from WidgetRegistry (no switch statements)
///   - Wrapped in ModuleErrorBoundary for graceful failure
///   - Shell-compliant: no Scaffold, no AppBar (owned by UnifiedAppShellV2)
/// ============================================================

/// Primary module page for Farm Management.
///
/// This page renders dashboard widgets registered via
/// ModuleRuntimeDescriptor contributions and resolved through
/// the WidgetRegistry. Widgets connect to live Riverpod providers
/// that fetch real data from repositories.
///
/// 🚀 On first build, triggers [farmSelectorProvider.notifier.loadFarms()]
/// to populate the farm selector with the user's farms.
class FarmManagementPage extends ConsumerStatefulWidget {
  const FarmManagementPage({super.key});

  @override
  ConsumerState<FarmManagementPage> createState() => _FarmManagementPageState();
}

class _FarmManagementPageState extends ConsumerState<FarmManagementPage> {
  bool _farmsLoaded = false;

  @override
  Widget build(BuildContext context) {
    // Trigger farm loading once on first build (farm selector auto-loading)
    if (!_farmsLoaded) {
      _farmsLoaded = true;
      ref.read(farmSelectorProvider.notifier).loadFarms();
    }

    // Resolve farm management widget descriptors from the runtime engine
    final descriptorsAsync = ref.watch(
      moduleWidgetDescriptorsProvider('farm_management'),
    );

    return ShellPageContent(
      title: 'Farm Management',
      subtitle: 'Manage your farms, fields, crops, and livestock',
      scrollable: false,
      child: descriptorsAsync.when(
        loading: () => const LoadingStateWidget(
          message: 'Loading farm dashboard...',
        ),
        error: (err, _) => _buildFallbackDashboard(context, ref),
        data: (descriptors) {
          if (descriptors.isEmpty) {
            return _buildFallbackDashboard(context, ref);
          }

          return _FarmDashboardGrid(
            descriptors: descriptors,
          );
        },
      ),
    );
  }

  /// Fallback dashboard that renders ALL registered farm widgets
  /// when descriptor resolution is unavailable or empty.
  Widget _buildFallbackDashboard(BuildContext context, WidgetRef ref) {
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
          _FarmDashboardTile(
            widgetKey: key,
            child: builder(),
          ),
        );
      }
    }

    if (resolvedWidgets.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.agriculture,
        title: 'Farm Dashboard',
        subtitle: 'Farm management widgets are not available. '
            'Please check your connection and try again.',
      );
    }
    return _FarmDashboardGridWidgets(widgets: resolvedWidgets);
  }
}

/// ============================================================
/// FARM DASHBOARD GRID (BACKED BY DESCRIPTORS)
/// ============================================================
///
/// Renders farm management widgets in a responsive grid layout.
/// Widget definitions come from the module runtime descriptors.
/// ============================================================
class _FarmDashboardGrid extends ConsumerWidget {
  final List<DashboardWidgetDescriptor> descriptors;

  const _FarmDashboardGrid({
    required this.descriptors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final breakpoint = ref.watch(breakpointProvider);
    final crossAxisCount = breakpoint.columnCount.clamp(1, 3);
    final isMobile = breakpoint.columnCount == 1;

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
            child: builder(),
          ),
        ));
      }
    }

    if (widgetEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.agriculture, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No widgets available',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by display order
    widgetEntries.sort(
      (a, b) => a.descriptor.displayOrder.compareTo(b.descriptor.displayOrder),
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isMobile ? 1.3 : 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widgetEntries.length,
      itemBuilder: (context, index) {
        final entry = widgetEntries[index];
        return _DashboardWidgetCard(
          descriptor: entry.descriptor,
          child: entry.widget,
        );
      },
    );
  }
}

/// ============================================================
/// FARM DASHBOARD GRID (FALLBACK — DIRECT WIDGET LIST)
/// ============================================================
class _FarmDashboardGridWidgets extends StatelessWidget {
  final List<Widget> widgets;

  const _FarmDashboardGridWidgets({required this.widgets});

  @override
  Widget build(BuildContext context) {
    // Use a simple static grid with responsive breakpoints
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 600 ? 1 : (width < 1024 ? 2 : 3);
    final isMobile = crossAxisCount == 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isMobile ? 1.3 : 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widgets.length,
      itemBuilder: (context, index) => widgets[index],
    );
  }
}

/// ============================================================
/// DASHBOARD WIDGET CARD WRAPPER
/// ============================================================
///
/// Wraps each dashboard widget in a consistent card container
/// with title, border, and hover effects.
/// ============================================================
class _DashboardWidgetCard extends StatelessWidget {
  final DashboardWidgetDescriptor descriptor;
  final Widget child;

  const _DashboardWidgetCard({
    required this.descriptor,
    required this.child,
  });

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
/// FARM DASHBOARD TILE (FALLBACK WRAPPER)
/// ============================================================
class _FarmDashboardTile extends StatelessWidget {
  final String widgetKey;
  final Widget child;

  const _FarmDashboardTile({
    required this.widgetKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// ============================================================
/// INTERNAL DATA MODEL
/// ============================================================
class _WidgetEntry {
  final DashboardWidgetDescriptor descriptor;
  final Widget widget;

  const _WidgetEntry({
    required this.descriptor,
    required this.widget,
  });
}

/// @deprecated Use [FarmManagementPage] instead.
typedef FarmDashboardPage = FarmManagementPage;