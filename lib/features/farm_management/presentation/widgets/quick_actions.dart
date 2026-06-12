import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';

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
                // TODO: Open activity creation dialog
                // Activity creation requires user input before calling controller
              },
              child: const Text('Add Activity'),
            ),
            ElevatedButton(
              onPressed: () async {
                // TODO: Open production recording form
                // Production recording requires user input before calling controller
              },
              child: const Text('Record Production'),
            ),
            ElevatedButton(
              onPressed: () async {
                // TODO: Confirm action before syncing
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

