import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/farm_dashboard_provider.dart';

class ProductionSummaryWidget extends ConsumerWidget {
  const ProductionSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(farmDashboardProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          loading: () => const Text('Loading production summary...'),
          error: (e, _) => Text('Failed to load production summary: $e'),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Production Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text('Total Production: ${data.summary.totalProduction}'),
              Text('Total Yield: ${data.summary.totalYield}'),
            ],
          ),
        ),
      ),
    );
  }
}

