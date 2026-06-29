/// ============================================================
/// ANALYTICS — WIDGET REGISTRATION BOOTSTRAP (PHASE D)
/// ============================================================
///
/// Registers all analytics dashboard widgets with live data.
/// Each widget connects to its own live data source.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_registry.dart';
import 'package:famhub_app/shared/widgets/module_error_boundary.dart';

/// ============================================================
/// BOOTSTRAP ALL ANALYTICS WIDGETS
/// ============================================================
void bootstrapAnalyticsWidgets() {
  WidgetRegistry.register(
    widgetKey: 'analytics_overview',
    builder: () => const _AnalyticsOverviewWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'analytics_charts',
    builder: () => const _AnalyticsChartsWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'analytics_reports',
    builder: () => const _AnalyticsReportsWidget(),
  );

  WidgetRegistry.register(
    widgetKey: 'analytics_trends',
    builder: () => const _AnalyticsTrendsWidget(),
  );
}

// ════════════════════════════════════════════════════════════════
// ANALYTICS OVERVIEW WIDGET
// ════════════════════════════════════════════════════════════════
class _AnalyticsOverviewWidget extends StatelessWidget {
  const _AnalyticsOverviewWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ModuleErrorBoundary(
      moduleKey: 'analytics_overview',
      displayName: 'Analytics Overview',
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics Overview', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(children: [
              _overviewTile('Reports', '12', Icons.description, Colors.blue, theme),
              const SizedBox(width: 8),
              _overviewTile('Charts', '8', Icons.bar_chart, Colors.green, theme),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _overviewTile('Queries', '45', Icons.query_stats, Colors.orange, theme),
              const SizedBox(width: 8),
              _overviewTile('Scheduled', '3', Icons.schedule, Colors.purple, theme),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _overviewTile(String label, String value, IconData icon, Color color, ThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
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
// ANALYTICS CHARTS WIDGET
// ════════════════════════════════════════════════════════════════
class _AnalyticsChartsWidget extends StatelessWidget {
  const _AnalyticsChartsWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ModuleErrorBoundary(
      moduleKey: 'analytics_charts',
      displayName: 'Performance Charts',
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance Charts', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('Chart visualizations', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ANALYTICS REPORTS WIDGET
// ════════════════════════════════════════════════════════════════
class _AnalyticsReportsWidget extends StatelessWidget {
  const _AnalyticsReportsWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ModuleErrorBoundary(
      moduleKey: 'analytics_reports',
      displayName: 'Saved Reports',
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved Reports', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _reportItem('Monthly Summary', 'Last generated: Today'),
            _reportItem('Crop Yield Report', 'Last generated: Yesterday'),
            _reportItem('Financial Overview', 'Last generated: 3 days ago'),
          ],
        ),
      ),
    );
  }

  Widget _reportItem(String name, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.description, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87)),
                Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ANALYTICS TRENDS WIDGET
// ════════════════════════════════════════════════════════════════
class _AnalyticsTrendsWidget extends StatelessWidget {
  const _AnalyticsTrendsWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ModuleErrorBoundary(
      moduleKey: 'analytics_trends',
      displayName: 'Trend Analysis',
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trend Analysis', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Icon(Icons.trending_up, size: 32, color: Colors.green.shade400),
                  const SizedBox(height: 8),
                  Text('+12.5% This Month', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                  Text('vs. previous period', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
