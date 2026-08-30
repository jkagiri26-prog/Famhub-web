import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/providers/module_degradation_provider.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/providers/operational_dashboard_provider.dart';

/// Marketplace Health Signal Widget
///
/// Integrates existing ModuleDegradationSnapshot and RuntimeHealthIndicators
/// at the marketplace dashboard level only.
/// Does NOT create marketplace-specific observability.
class MarketplaceHealthWidget extends ConsumerWidget {
  const MarketplaceHealthWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final degradation = ref.watch(moduleDegradationProvider);
    final dashboard = ref.watch(operationalDashboardProvider);

    final marketplaceEntry = degradation.forModule('marketplace');
    final isHealthy = marketplaceEntry?.isHealthy ?? true;

    if (isHealthy && dashboard.overallHealth.name == 'healthy') {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHealthy ? Colors.orange.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHealthy ? Colors.orange.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.warning_amber_rounded : Icons.error_outline,
            size: 18,
            color: isHealthy ? Colors.orange.shade600 : Colors.red.shade600,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy
                      ? 'System Degraded'
                      : marketplaceEntry?.reason ?? 'Service Issue Detected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isHealthy
                        ? Colors.orange.shade800
                        : Colors.red.shade800,
                  ),
                ),
                if (marketplaceEntry != null && !isHealthy)
                  Text(
                    'Recovery attempts: ${marketplaceEntry.recoveryAttemptCount}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
