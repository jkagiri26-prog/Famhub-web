/// ============================================================
/// FARM HEALTH INDICATOR — LIVE PROVIDER WIDGET
/// ============================================================
///
/// ✅ CONSUMES:
///   - farmDashboardProvider (existing provider)
///   - moduleDegradationProvider (existing runtime provider)
///
/// ✅ RESPONSIBILITIES:
///   - Show farm health status based on real KPI data
///   - Display module health indicators
///   - Provide at-a-glance status
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/module_degradation_provider.dart';

class FarmHealthIndicator extends ConsumerWidget {
  const FarmHealthIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(farmDashboardProvider);
    final degradationSnapshot = ref.watch(moduleDegradationProvider);
    final hasDegradation = degradationSnapshot.degradedCount > 0;

    return dashboardAsync.when(
      loading: () => _buildSkeleton(),
      error: (e, _) => _buildError(context, e.toString()),
      data: (data) {
        final summary = data.summary;
        final profit = summary.totalSales - summary.totalExpenses;
        
        HealthStatus status;
        if (hasDegradation) {
          status = HealthStatus.warning;
        } else if (profit < 0) {
          status = HealthStatus.attention;
        } else if (summary.totalProduction > 0) {
          status = HealthStatus.good;
        } else {
          status = HealthStatus.neutral;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(status.icon, size: 22, color: status.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Farm Health',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: status.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDegradation)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${degradationSnapshot.degradedCount} issue${degradationSnapshot.degradedCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
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
      height: 76,
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

enum HealthStatus {
  good('All Systems Good', Icons.check_circle_rounded, Colors.green),
  warning('Minor Issues', Icons.warning_amber_rounded, Colors.orange),
  attention('Needs Attention', Icons.error_outline_rounded, Colors.red),
  neutral('No Data', Icons.help_outline_rounded, Colors.grey);

  final String label;
  final IconData icon;
  final Color color;

  const HealthStatus(this.label, this.icon, this.color);
}
