import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/farm_dashboard_provider.dart';

class ActivityTimelineWidget extends ConsumerWidget {
  const ActivityTimelineWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(farmDashboardProvider);

    return state.when(
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Loading activities...'),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Failed to load activities: $e'),
        ),
      ),
      data: (data) {
        final activities = data.todayActivities;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's Activities",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (activities.isEmpty)
                  const Text('No activities for today.')
                else
                  ...activities.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• ${a.notes ?? a.activityTypeId}'),
                      )),
              ],
            ),
          ),
        );
      },
    );
  }
}

