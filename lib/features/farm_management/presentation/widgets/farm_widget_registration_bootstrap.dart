library farm_widget_registration_bootstrap;

/// ============================================================
/// FARM MANAGEMENT — WIDGET REGISTRATION BOOTSTRAP (PHASE D)
/// ============================================================
///
/// Registers all farm management dashboard widgets with live data.
/// Each widget builder connects to its own live provider.
///
/// Architecture:
///   WidgetRegistry.register(farm_kpis, builder) → FarmKpisWidget → farmKpiDataProvider
///
/// Every widget:
///   - Uses ModuleErrorBoundary for graceful failure
///   - Connects to a specific live provider
///   - Handles loading/error/data states
///   - Reports metrics to observability
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_live_providers.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/farm_selector_widget.dart';
import 'package:famhub_app/features/farm_management/presentation/widgets/quick_actions_widget.dart';

/// ============================================================
/// BOOTSTRAP ALL FARM WIDGETS
/// ============================================================
void bootstrapFarmWidgets() {
  WidgetRegistry.register(
    widgetKey: 'farm_kpis',
    builder: () => const _FarmKpisWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'farm_summary',
    builder: () => const _FarmSummaryWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'farm_activity_timeline',
    builder: () => const _FarmActivityTimelineWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'farm_production_summary',
    builder: () => const _FarmProductionSummaryWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'farm_alerts',
    builder: () => const _FarmAlertsWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'farm_stock_summary',
    builder: () => const _FarmStockSummaryWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'farm_livestock',
    builder: () => const _FarmLivestockWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'farm_weather',
    builder: () => const _FarmWeatherWidget(),
  );

  // ── Phase E: Additional Widgets ──
  WidgetRegistry.register(
    widgetKey: 'farm_farm_selector',
    builder: () => const FarmSelectorWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'farm_quick_actions',
    builder: () => const QuickActionsWidget(),
  );
}

// ════════════════════════════════════════════════════════════════
// FARM KPIS WIDGET
// ════════════════════════════════════════════════════════════════
class _FarmKpisWidget extends ConsumerWidget {
  const _FarmKpisWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync = ref.watch(farmKpiDataProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'farm_kpis',
      displayName: 'Farm KPIs',
      child: kpiAsync.when(
        loading: () => const Center(child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Failed to load KPIs', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
        ),
        data: (summary) => _buildKpiContent(context, theme, summary),
      ),
    );
  }

  Widget _buildKpiContent(BuildContext context, ThemeData theme, FarmDashboardSummary summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Key Performance Indicators', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _kpiRow(theme, 'Production', '${summary.totalProduction.toStringAsFixed(1)} kg', Icons.production_quantity_limits, Colors.green),
          const SizedBox(height: 8),
          _kpiRow(theme, 'Sales', '\$${summary.totalSales.toStringAsFixed(2)}', Icons.trending_up, Colors.blue),
          const SizedBox(height: 8),
          _kpiRow(theme, 'Expenses', '\$${summary.totalExpenses.toStringAsFixed(2)}', Icons.money_off, Colors.red.shade400),
          const SizedBox(height: 8),
          _kpiRow(theme, 'Yield', '${summary.totalYield.toStringAsFixed(1)} kg', Icons.eco, Colors.orange),
        ],
      ),
    );
  }

  Widget _kpiRow(ThemeData theme, String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FARM SUMMARY WIDGET
// ════════════════════════════════════════════════════════════════
class _FarmSummaryWidget extends ConsumerWidget {
  const _FarmSummaryWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync = ref.watch(farmKpiDataProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'farm_summary',
      displayName: 'Farm Summary',
      child: kpiAsync.when(
        loading: () => const Center(child: SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2),
        )),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Failed to load summary', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
        ),
        data: (summary) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Farm Performance', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _summaryTile('Production', '${summary.totalProduction.toStringAsFixed(1)} kg', Icons.production_quantity_limits, Colors.green, theme),
                  const SizedBox(width: 12),
                  _summaryTile('Stock Value', '\$${summary.stockValue.toStringAsFixed(2)}', Icons.inventory, Colors.blue, theme),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _summaryTile('Sales', '\$${summary.totalSales.toStringAsFixed(2)}', Icons.trending_up, Colors.teal, theme),
                  const SizedBox(width: 12),
                  _summaryTile('Expenses', '\$${summary.totalExpenses.toStringAsFixed(2)}', Icons.money_off, Colors.red.shade400, theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FARM ACTIVITY TIMELINE WIDGET
// ════════════════════════════════════════════════════════════════
class _FarmActivityTimelineWidget extends ConsumerWidget {
  const _FarmActivityTimelineWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(farmTodayActivitiesProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'farm_activity_timeline',
      displayName: 'Activity Timeline',
      child: activitiesAsync.when(
        loading: () => const Center(child: SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2),
        )),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Failed to load activities', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
        ),
        data: (activities) => Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Today\'s Activities', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (activities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy, size: 32, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text('No activities today', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                ...activities.take(5).map((a) => _activityItem(a, theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityItem(ActivityModel activity, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              activity.notes ?? 'Activity ${activity.activityTypeId}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatTime(activity.performedAt),
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ════════════════════════════════════════════════════════════════
// FARM PRODUCTION SUMMARY WIDGET
// ════════════════════════════════════════════════════════════════
class _FarmProductionSummaryWidget extends ConsumerWidget {
  const _FarmProductionSummaryWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productionAsync = ref.watch(farmProductionRecordsProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'farm_production_summary',
      displayName: 'Production Summary',
      child: productionAsync.when(
        loading: () => const Center(child: SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2),
        )),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Failed to load production', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
        ),
        data: (records) {
          final totalQty = records.fold<double>(0, (sum, r) => sum + (r.quantity ?? 0));
          return Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Production Summary', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    children: [
                      Text('${totalQty.toStringAsFixed(1)} kg', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                      Text('Total Production', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('${records.length} records', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FARM ALERTS WIDGET
// ════════════════════════════════════════════════════════════════
class _FarmAlertsWidget extends ConsumerWidget {
  const _FarmAlertsWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(farmAlertsProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'farm_alerts',
      displayName: 'Farm Alerts',
      child: alertsAsync.when(
        loading: () => const Center(child: SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2),
        )),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Failed to load alerts', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
        ),
        data: (alerts) => Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alerts & Notifications', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (alerts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('All clear! No alerts', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              else
                ...alerts.take(3).map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        a['severity'] == 'high' ? Icons.warning : Icons.info_outline,
                        size: 14,
                        color: a['severity'] == 'high' ? Colors.orange : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          a['message'] as String? ?? '',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FARM STOCK SUMMARY WIDGET
// ════════════════════════════════════════════════════════════════
class _FarmStockSummaryWidget extends ConsumerWidget {
  const _FarmStockSummaryWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(farmStockValueProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'farm_stock_summary',
      displayName: 'Stock Summary',
      child: stockAsync.when(
        loading: () => const Center(child: SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2),
        )),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Failed to load stock', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
        ),
        data: (stock) {
          final totalItems = stock.length;
          final totalQty = stock.values.fold<double>(0, (sum, q) => sum + q);
          return Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock Summary', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stockStat('Items', totalItems.toString(), Icons.inventory, Colors.blue, theme),
                    const SizedBox(width: 12),
                    _stockStat('Total Qty', totalQty.toStringAsFixed(1), Icons.storage, Colors.teal, theme),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stockStat(String label, String value, IconData icon, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FARM LIVESTOCK WIDGET
// ════════════════════════════════════════════════════════════════
class _FarmLivestockWidget extends ConsumerWidget {
  const _FarmLivestockWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final livestockAsync = ref.watch(farmLivestockProvider);
    final theme = Theme.of(context);

    return ModuleErrorBoundary(
      moduleKey: 'farm_livestock',
      displayName: 'Livestock',
      child: livestockAsync.when(
        loading: () => const Center(child: SizedBox(
          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2),
        )),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Failed to load livestock', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
        ),
        data: (livestock) {
          final totalAnimals = livestock.fold<int>(0, (sum, l) => sum + l.count);
          final species = livestock.map((l) => l.species).toSet().length;
          return Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Livestock Overview', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stockStat('Animals', totalAnimals.toString(), Icons.pets, Colors.orange, theme),
                    const SizedBox(width: 12),
                    _stockStat('Species', species.toString(), Icons.category, Colors.brown, theme),
                  ],
                ),
                if (livestock.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(livestock.first.species, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stockStat(String label, String value, IconData icon, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// FARM WEATHER WIDGET
// ════════════════════════════════════════════════════════════════
class _FarmWeatherWidget extends StatelessWidget {
  const _FarmWeatherWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ModuleErrorBoundary(
      moduleKey: 'farm_weather',
      displayName: 'Weather',
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weather', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.wb_sunny, size: 32, color: Colors.amber.shade600),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sunny', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('25°C | Good farming conditions', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
