import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/feature_page_scaffold.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/activity_feed_widget.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';

import 'package:famhub_app/features/farm_management/application/providers/activities_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';

class ActivitiesPage extends ConsumerStatefulWidget {
  const ActivitiesPage({super.key});

  @override
  ConsumerState<ActivitiesPage> createState() => _ActivitiesPageState();
}

class _ActivitiesPageState extends ConsumerState<ActivitiesPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadActivities());
  }

  Future<void> _loadActivities() async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId != null) {
      ref.read(activitiesProvider(farmId).notifier).loadActivities();
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;

    if (farmId == null) {
      return const FeaturePageScaffold(
        title: 'Activities',
        subtitle: 'Select a farm to view activities',
        children: [],
      );
    }

    final activityState = ref.watch(activitiesProvider(farmId));

    if (activityState.isLoading) {
      return const FeaturePageScaffold(
        title: 'Activities',
        subtitle: 'Loading activity timeline...',
        children: [LoadingStateWidget(useSkeleton: true)],
      );
    }

    if (activityState.errorMessage != null) {
      return FeaturePageScaffold(
        title: 'Activities',
        subtitle: 'Failed to load activity data',
        children: [
          ErrorStateWidget(
            title: 'Error Loading Activities',
            message: activityState.errorMessage!,
            retryLabel: 'Retry',
            onRetry: _loadActivities,
          ),
        ],
      );
    }

    final activities = activityState.activities;

    // Convert to shared ActivityItem list
    final feedItems = activities.map((act) {
      return ActivityItem(
        title: _activityLabel(act.activityTypeId),
        subtitle: act.notes,
        icon: _activityIcon(act.activityTypeId),
        color: _activityColor(act.activityTypeId),
        timestamp: _formatTimestamp(act.performedAt),
      );
    }).toList();

    return FeaturePageScaffold(
      title: 'Activities',
      subtitle: '${activities.length} activit${activities.length == 1 ? 'y' : 'ies'}',
      children: [
        // ── KPIs ──
        AdaptiveContentGrid(
          items: [
            KPICard(
              label: 'Total Activities',
              value: '${activities.length}',
              icon: Icons.list_alt,
              iconColor: Colors.blue,
            ),
            KPICard(
              label: 'Today\'s Activities',
              value: '${activities.where((a) =>
                a.performedAt.day == DateTime.now().day &&
                a.performedAt.month == DateTime.now().month &&
                a.performedAt.year == DateTime.now().year
              ).length}',
              icon: Icons.today,
              iconColor: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Activity Feed ──
        Expanded(
          child: ActivityFeedWidget(
            activities: feedItems,
            emptyTitle: 'No farm activities yet',
            emptySubtitle: 'Start recording farm operations and events.',
          ),
        ),
      ],
    );
  }

  String _activityLabel(String typeId) {
    // Map activity type IDs to readable labels
    if (typeId.length >= 8) {
      return 'Activity ${typeId.substring(0, 8)}';
    }
    return 'Activity';
  }

  IconData _activityIcon(String typeId) {
    // Map activity types to icons (expand as activity_types table grows)
    return Icons.event_note;
  }

  Color _activityColor(String typeId) {
    // Map activity types to colors
    return Colors.blue;
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

