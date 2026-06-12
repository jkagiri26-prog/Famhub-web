import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';

class FarmSelectorWidget extends ConsumerWidget {
  const FarmSelectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(farmSelectorProvider);
    final controller = ref.read(farmSelectorProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Farm Selector',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (state.isLoading)
              const CircularProgressIndicator()
            else if (state.farms.isEmpty)
              const Text('No farms available for this account.')
            else
              DropdownButton<String>(
                value: state.selectedFarmId,
                isExpanded: true,
                items: state.farms
                    .map(
                      (farm) => DropdownMenuItem<String>(
                        value: farm.id,
                        child: Text(farm.farmName),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) controller.selectFarm(value);
                },
              ),
          ],
        ),
      ),
    );
  }
}

