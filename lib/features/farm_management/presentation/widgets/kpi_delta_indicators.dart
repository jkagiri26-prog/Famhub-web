// ignore: dangling_library_doc_comments
/// ============================================================
/// KPI DELTA INDICATORS — LIVE PROVIDER WIDGETS
/// ============================================================
///
/// ✅ CONSUMES:
///   - farmDashboardProvider (existing async provider)
///
/// ✅ RESPONSIBILITIES:
///   - Show KPI values with trend indicators
///   - Track production, sales, expenses changes
///   - Render using shared KPICard widget
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';

class KpiDeltaIndicators extends ConsumerWidget {
  const KpiDeltaIndicators({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(farmDashboardProvider);

    return dashboardAsync.when(
      loading: () => _buildSkeletonGrid(),
      error: (e, _) => _buildError(context, e.toString()),
      data: (data) {
        final summary = data.summary;
        final profit = summary.totalSales - summary.totalExpenses;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 500;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _deltaTile(
                  context,
                  label: 'Production',
                  value: summary.totalProduction.toStringAsFixed(1),
                  icon: Icons.grass_rounded,
                  color: Colors.green,
                  isUp: summary.totalProduction > 0,
                ),
                _deltaTile(
                  context,
                  label: 'Revenue',
                  value: summary.totalSales.toStringAsFixed(1),
                  icon: Icons.trending_up_rounded,
                  color: Colors.green.shade700,
                  isUp: summary.totalSales > 0,
                ),
                _deltaTile(
                  context,
                  label: 'Expenses',
                  value: summary.totalExpenses.toStringAsFixed(1),
                  icon: Icons.trending_down_rounded,
                  color: Colors.red.shade400,
                  isUp: false,
                ),
                _deltaTile(
                  context,
                  label: 'Profit',
                  value: profit.toStringAsFixed(1),
                  icon: profit >= 0
                      ? Icons.savings_rounded
                      : Icons.money_off_rounded,
                  color: profit >= 0 ? Colors.blue : Colors.red,
                  isUp: profit >= 0,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _deltaTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isUp,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        4,
        (i) => Container(
          width: 150,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
