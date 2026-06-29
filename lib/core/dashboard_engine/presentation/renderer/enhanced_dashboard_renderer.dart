/// ============================================================
/// ENHANCED DASHBOARD RENDERER (ENTERPRISE PHASE 2)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/presentation/renderer/ = dashboard renderer
///
/// ✅ Responsibilities:
///   - Render dashboard from DashboardWidgetDescriptors
///   - Organized by section, priority, display order
///   - Supports: KPIs, Charts, Tables, Feeds, Tasks, Weather,
///     Marketplace, Farm summary, Finance, Traceability,
///     Knowledge, AI widgets
///   - Each widget resolved from WidgetRegistry dynamically
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Widget list comes from RuntimeDescriptorEngine
///   - No hardcoded widget lists or sections
///   - Responsive grid layout per device
///   - Each widget wrapped in ModuleErrorBoundary
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/composition/domain/models/section_registry.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';
import 'package:famhub_app/shared/utils/icon_resolver.dart';

/// ============================================================
/// ENHANCED DASHBOARD RENDERER
/// ============================================================
///
/// Replaces placeholder dashboard cards with dynamic
/// section-based rendering from DashboardWidgetDescriptors.
/// ============================================================
class EnhancedDashboardRenderer extends ConsumerWidget {
  const EnhancedDashboardRenderer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;

    // Watch widgets organized by section from runtime descriptors
    final widgetsAsync = ref.watch(dashboardWidgetsBySectionProvider);

    // Determine device layout
    final isMobile = width < 600;
    final crossAxisCount = width > 900 ? 3 : (width > 600 ? 2 : 1);

    return widgetsAsync.when(
      loading: () => const _DashboardLoading(),
      error: (err, _) => Center(
        child: Text('Dashboard error: $err',
          style: TextStyle(color: Colors.red.shade600)),
      ),
      data: (sectionMap) {
        if (sectionMap.isEmpty) {
          return const _DashboardEmpty();
        }

        return SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Dashboard Header ──
                    _buildHeader(sectionMap.length, theme),
                    const SizedBox(height: 16),

                    // ── Dynamic Sections ──
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: sectionMap.entries.length,
                        itemBuilder: (context, index) {
                          final entry = sectionMap.entries.elementAt(index);
                          return _DashboardSectionWidget(
                            sectionKey: entry.key,
                            widgets: entry.value,
                            crossAxisCount: crossAxisCount,
                            theme: theme,
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
      },
    );
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
}

/// ============================================================
/// DASHBOARD SECTION WIDGET
/// ============================================================
class _DashboardSectionWidget extends StatelessWidget {
  final String sectionKey;
  final List<DashboardWidgetDescriptor> widgets;
  final int crossAxisCount;
  final ThemeData theme;

  const _DashboardSectionWidget({
    required this.sectionKey,
    required this.widgets,
    required this.crossAxisCount,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final sectionName = _resolveSectionName(sectionKey);
    final sectionIcon = IconResolver.resolve(_resolveSectionIcon(sectionKey));

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
                  sectionName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widgets.length} widget${widgets.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // ── Section Content Grid ──
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount.clamp(1, 3),
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: widgets.length,
            itemBuilder: (context, index) {
              final widgetDef = widgets[index];

              // Try to resolve a registered widget builder
              final widgetBuilder = WidgetRegistry.resolve(widgetDef.widgetKey);
              if (widgetBuilder != null) {
                return ModuleErrorBoundary(
                  moduleKey: widgetDef.widgetKey,
                  displayName: widgetDef.displayName,
                  child: widgetBuilder(),
                );
              }

              // Fallback card rendering
              return _WidgetFallbackCard(
                widgetDef: widgetDef,
                theme: theme,
              );
            },
          ),
        ],
      ),
    );
  }

  String _resolveSectionName(String key) {
    return SectionRegistry.displayName(key);
  }

  String _resolveSectionIcon(String key) {
    // Map SectionRegistry icon data to icon key strings for IconResolver
    const iconMap = <String, String>{
      'Farm Overview': 'agriculture',
      'Marketplace': 'store',
      'Finance': 'account_balance',
      'Analytics': 'analytics',
      'Logistics': 'local_shipping',
      'Traceability': 'track_changes',
      'Sustainability': 'eco',
      'Knowledge': 'school',
      'Community': 'people',
      'Opportunities': 'trending_up',
      'Administration': 'admin_panel_settings',
      'Weather': 'wb_sunny',
      'Profile': 'person',
    };
    final name = SectionRegistry.displayName(key);
    return iconMap[name] ?? 'widgets';
  }
}

/// ============================================================
/// WIDGET FALLBACK CARD
/// ============================================================
class _WidgetFallbackCard extends StatelessWidget {
  final DashboardWidgetDescriptor widgetDef;
  final ThemeData theme;

  const _WidgetFallbackCard({
    required this.widgetDef,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final icon = IconResolver.resolve(widgetDef.iconKey);

    return ModuleErrorBoundary(
      moduleKey: widgetDef.widgetKey,
      displayName: widgetDef.displayName,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: theme.colorScheme.primary),
                  ),
                  const Spacer(),
                  if (widgetDef.refreshIntervalSeconds > 0)
                    Icon(Icons.refresh, size: 12, color: Colors.grey.shade400),
                ],
              ),
              const Spacer(),
              Text(
                widgetDef.displayName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${widgetDef.width}x${widgetDef.height}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.open_in_new,
                    size: 12,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// LOADING STATE
/// ============================================================
class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// ============================================================
/// EMPTY STATE
/// ============================================================
class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize_outlined,
              size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Dashboard Empty',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('No dashboard widgets are configured.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
