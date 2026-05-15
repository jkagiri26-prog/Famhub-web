import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/admin_service_provider.dart';

class SubscriptionTierEditor extends ConsumerStatefulWidget {
  const SubscriptionTierEditor({super.key});

  @override
  ConsumerState<SubscriptionTierEditor> createState() =>
      _SubscriptionTierEditorState();
}

class _SubscriptionTierEditorState
    extends ConsumerState<SubscriptionTierEditor> {
  final TextEditingController featureController =
      TextEditingController();

  String selectedTier = 'free';

  final List<String> tiers = const [
    'free',
    'basic',
    'premium',
    'enterprise',
  ];

  @override
  Widget build(BuildContext context) {
    final adminService = ref.watch(adminServiceProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: featureController,
              decoration: const InputDecoration(
                labelText: 'Feature Key',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedTier,
              items: tiers
                  .map(
                    (tier) => DropdownMenuItem(
                      value: tier,
                      child: Text(tier),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedTier = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Required Subscription Tier',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await adminService.updateFeatureTier(
                  featureController.text.trim(),
                  selectedTier,
                );
              },
              child: const Text('Update Tier'),
            ),
          ],
        ),
      ),
    );
  }
}