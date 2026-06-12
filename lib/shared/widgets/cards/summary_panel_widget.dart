/// ============================================================
/// SUMMARY PANEL WIDGET (REUSABLE DASHBOARD SUMMARY)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/cards/ = reusable card widgets
///
/// ✅ Responsibilities:
///   - Display multiple KPI metrics in a row/grid
///   - Responsive layout adaptation
///   - Reusable across all modules
///
/// ❌ Does NOT:
///   - Reference registries or providers
///   - Contain business logic
/// ============================================================

import 'package:flutter/material.dart';

class SummaryPanelWidget extends StatelessWidget {
  final List<SummaryMetric> metrics;
  final int? crossAxisCount;

  const SummaryPanelWidget({
    super.key,
    required this.metrics,
    this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = crossAxisCount ??
            (constraints.maxWidth > 600
                ? (constraints.maxWidth > 900 ? 4 : 3)
                : 2);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: 1.6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _buildMetricCard(context, metric);
          },
        );
      },
    );
  }

  Widget _buildMetricCard(BuildContext context, SummaryMetric metric) {
    final theme = Theme.of(context);
    final color = metric.color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                metric.icon,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  metric.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });
}
