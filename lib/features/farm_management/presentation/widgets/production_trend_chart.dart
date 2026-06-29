// ignore: dangling_library_doc_comments
/// ============================================================
/// PRODUCTION TREND CHART — LIVE PROVIDER WIDGET
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/presentation/dashboard/widgets/
///
/// ✅ CONSUMES:
///   - farmDashboardProvider (existing async provider)
///
/// ✅ RESPONSIBILITIES:
///   - Render production trend using fl_chart
///   - Show loading/error/empty states
///   - React to provider invalidation
///
/// ❌ Does NOT:
///   - Duplicate business logic
///   - Call Supabase directly
///   - Bypass repository layer
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';

class ProductionTrendChart extends ConsumerWidget {
  const ProductionTrendChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(farmDashboardProvider);

    return dashboardAsync.when(
      loading: () => _buildSkeleton(),
      error: (e, _) => _buildError(context, e.toString()),
      data: (data) {
        final summary = data.summary;
        
        // Build spots from real data
        final spots = [
          const FlSpot(0, 0),
          FlSpot(1, summary.totalYield),
          FlSpot(2, summary.totalProduction),
        ];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      size: 18,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Production Trend',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                child: spots.length > 1
                    ? LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) => FlLine(
                              color: Colors.grey.shade100,
                              strokeWidth: 1,
                            ),
                          ),
                          titlesData: const FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: Colors.green,
                              barWidth: 2.5,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) =>
                                    FlDotCirclePainter(
                                  radius: 3,
                                  color: Colors.green,
                                  strokeWidth: 0,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.green.withValues(alpha: 0.08),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Text(
                          'Insufficient data for trend',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
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
