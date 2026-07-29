/// ============================================================
/// FARM ONBOARDING CHECKLIST WIDGET
/// ============================================================
///
/// 🏗️ COMPLETION CHECKLIST:
///   Displayed for new farms to track setup progress.
///   Automatically marks items complete as the farmer progresses.
///   Hides once all items are complete.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_onboarding_provider.dart';

class FarmOnboardingChecklistWidget extends ConsumerWidget {
  const FarmOnboardingChecklistWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(farmOnboardingProvider);

    if (!state.showChecklist) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final checklist = state.checklist;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Text(
                'Farm Setup',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${checklist.completedCount} / ${checklist.totalCount}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── Progress bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: checklist.completedCount / checklist.totalCount,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(Colors.green.shade500),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),

          // ── Checklist Items ──
          _buildCheckItem(
            context,
            completed: checklist.farmCreated,
            label: 'Farm Created',
          ),
          const SizedBox(height: 8),
          _buildCheckItem(
            context,
            completed: checklist.mainFieldCreated,
            label: 'Main Field Created',
          ),
          const SizedBox(height: 8),
          _buildCheckItem(
            context,
            completed: checklist.firstCropOrLivestockAdded,
            label: 'Add First Crop or Livestock',
          ),
          const SizedBox(height: 8),
          _buildCheckItem(
            context,
            completed: checklist.firstActivityRecorded,
            label: 'Record First Activity',
          ),
          const SizedBox(height: 8),
          _buildCheckItem(
            context,
            completed: checklist.firstReportViewed,
            label: 'View First Report',
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(
    BuildContext context, {
    required bool completed,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: completed ? Colors.green.shade500 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(11),
          ),
          child: completed
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: completed ? FontWeight.w600 : FontWeight.w400,
            color: completed ? Colors.green.shade700 : Colors.grey.shade600,
            decoration: completed ? TextDecoration.lineThrough : null,
            decorationColor: Colors.green.shade300,
          ),
        ),
      ],
    );
  }
}
