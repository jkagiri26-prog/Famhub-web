/// ============================================================
/// FARM SETUP GUIDE WIDGET
/// ============================================================
///
/// 🏗️ GUIDED NEXT STEP:
///   Displayed at the top of the dashboard when the farm has
///   no crops and no livestock.
///
///   Prompts the user to add their first crop or livestock.
///   Automatically hides after the first addition.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_onboarding_provider.dart';
import 'package:famhub_app/features/farm_management/presentation/navigation/farm_action_navigation.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_crop_page.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/add_livestock_page.dart';

/// Guided setup card shown when a farm has no crops and no livestock.
class FarmSetupGuideWidget extends ConsumerWidget {
  const FarmSetupGuideWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(farmOnboardingProvider);

    if (!onboardingState.showSetupGuide) {
      return const SizedBox.shrink();
    }

    return _buildGuideCard(context, ref);
  }

  Widget _buildGuideCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade50,
            Colors.teal.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title Row ──
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.rocket_launch,
                  size: 22,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're ready to start farming!",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your Main Field has already been created. What would you like to add first?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Dismiss button ──
              IconButton(
                onPressed: () {
                  ref.read(farmOnboardingProvider.notifier).dismissSetupGuide();
                },
                icon: Icon(Icons.close, size: 18, color: Colors.green.shade400),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Action Buttons ──
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => ensureFieldSelectedAndOpen(
                    context,
                    ref,
                    (_) => const AddCropPage(),
                  ),
                  icon: const Icon(Icons.eco, size: 18),
                  label: const Text('Add Crop'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => ensureFieldSelectedAndOpen(
                    context,
                    ref,
                    (_) => const AddLivestockPage(),
                  ),
                  icon: const Icon(Icons.pets, size: 18),
                  label: const Text('Add Livestock'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
