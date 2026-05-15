import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/farm_dashboard_provider.dart';
import '../../../domain/models/activity_model.dart';
import '../../../domain/models/production_model.dart';

class FarmQuickActions extends ConsumerWidget {
  const FarmQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(farmDashboardProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: () async {
                await controller.createActivity(
                  ActivityModel(
                    id: 'new-activity',
                    activityTypeId: 'mock-activity-type',
                    performedAt: DateTime.now(),
                    notes: 'New farm activity',
                  ),
                );
              },
              child: const Text('Add Activity'),
            ),
            ElevatedButton(
              onPressed: () async {
                await controller.recordProduction(
                  const ProductionModel(
                    id: 'new-production',
                    farmId: 'selected-on-server',
                    quantity: 0,
                  ),
                );
              },
              child: const Text('Record Production'),
            ),
            ElevatedButton(
              onPressed: () async {
                await controller.syncMarketplaceListing();
              },
              child: const Text('Sell to Marketplace'),
            ),
          ],
        ),
      ),
    );
  }
}

