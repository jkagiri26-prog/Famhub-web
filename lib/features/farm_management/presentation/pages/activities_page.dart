import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/shared/layouts/shell_page_content.dart';
import 'package:famhub_app/shared/widgets/states/loading_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/empty_state_widget.dart';
import 'package:famhub_app/shared/widgets/states/error_state_widget.dart';
import 'package:famhub_app/shared/widgets/activity_feed_widget.dart';
import 'package:famhub_app/shared/widgets/cards/kpi_card.dart';
import 'package:famhub_app/shared/layouts/adaptive_content_grid.dart';

import 'package:famhub_app/features/farm_management/application/providers/activities_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

import 'package:famhub_app/features/farm_management/presentation/pages/activity_creation_page.dart';

/// Activity type metadata mapping.
/// Source of truth for activity labels, icons, and colors.
class ActivityTypeMap {
  static const _types = <String, _TypeInfo>{
    'general': _TypeInfo('General Activity', Icons.event_note, Colors.blue),
    'planting': _TypeInfo('Planting', Icons.eco, Colors.green),
    'irrigation': _TypeInfo('Irrigation', Icons.water_drop, Colors.cyan),
    'fertilizing': _TypeInfo('Fertilizing', Icons.biotech, Colors.teal),
    'pest_control': _TypeInfo('Pest Control', Icons.bug_report, Colors.orange),
    'harvesting': _TypeInfo('Harvesting', Icons.shopping_basket, Colors.green),
    'maintenance': _TypeInfo('Maintenance', Icons.build, Colors.blueGrey),
    'feeding': _TypeInfo('Feeding', Icons.restaurant, Colors.brown),
    'milking': _TypeInfo('Milking', Icons.water, Colors.lightBlue),
    'vaccination': _TypeInfo('Vaccination', Icons.medical_services, Colors.red),
    'inspection': _TypeInfo('Inspection', Icons.visibility, Colors.purple),
    'transport': _TypeInfo('Transport', Icons.local_shipping, Colors.indigo),
    'other': _TypeInfo('Other', Icons.more_horiz, Colors.grey),
  };

  static String label(String typeId) =>
      _types[typeId]?.label ?? 'Activity ($typeId)';

  static IconData icon(String typeId) =>
      _types[typeId]?.icon ?? Icons.event_note;

  static Color color(String typeId) =>
      _types[typeId]?.color ?? Colors.blue;
}

class _TypeInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _TypeInfo(this.label, this.icon, this.color);
}

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
      ref.read(activitiesProvider.notifier).loadActivities();
    }
  }

    @override
  Widget build(BuildContext context) {
    final farmId = ref.watch(farmContextProvider).farmId;
    final hierarchy = ref.watch(hierarchyProvider);

        if (farmId == null) {
      return const ShellPageContent(
        title: 'Activities',
        subtitle: 'Select a farm to view activities',
        child: SizedBox.shrink(),
      );
    }

    // 🚫 BLOCK: Activities require a Crop or Livestock to be selected
    if (!hierarchy.hasCropOrLivestock) {
      return ShellPageContent(
        title: 'Activities',
        subtitle: 'Select a field AND crop/livestock to view activities',
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Select a Field and Crop/Livestock first',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  'Open the My Farms tab, select a farm and field, then open '
                  'Crops or Livestock and tap a specific record. '
                  'Then you can view and record activities.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activityState = ref.watch(activitiesProvider);

    if (activityState.isLoading) {
      return const ShellPageContent(
        title: 'Activities',
        subtitle: 'Loading activity timeline...',
        child: LoadingStateWidget(useSkeleton: true),
      );
    }

    if (activityState.errorMessage != null) {
      return ShellPageContent(
        title: 'Activities',
        subtitle: 'Failed to load activity data',
        child: ErrorStateWidget(
          title: 'Error Loading Activities',
          message: activityState.errorMessage!,
          retryLabel: 'Retry',
          onRetry: _loadActivities,
        ),
      );
    }

    final activities = activityState.activities;

    // Convert to shared ActivityItem list with type-aware mapping
    final feedItems = activities.map((act) {
      return ActivityItem(
        title: ActivityTypeMap.label(act.activityTypeId),
        subtitle: act.notes,
        icon: ActivityTypeMap.icon(act.activityTypeId),
        color: ActivityTypeMap.color(act.activityTypeId),
        timestamp: _formatTimestamp(act.performedAt),
      );
    }).toList();

        return ShellPageContent(
      title: 'Activities',
      subtitle: hierarchy.hasCropOrLivestock
          ? '${hierarchy.cropOrLivestockType == 'livestock' ? '🐄' : '🌱'} ${hierarchy.cropOrLivestockType == 'livestock' ? (hierarchy.cropOrLivestock as dynamic)?.species ?? 'Livestock' : (hierarchy.cropOrLivestock as dynamic)?.cropName ?? 'Crop'} — ${activities.length} activities'
          : '${activities.length} activit${activities.length == 1 ? 'y' : 'ies'}',
      actions: [
        // ✅ CONTEXT: Record Activity ONLY when a Crop/Livestock is selected
        if (hierarchy.hasCropOrLivestock)
          IconButton(
            onPressed: () => _navigateToCreateActivity(context),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Record Activity',
          ),
      ],
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

        // ── Create Activity Button (quick action) ──
        if (activities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _navigateToCreateActivity(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Record New Activity'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

        // ── Activity Feed ──
        Expanded(
          child: activities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'No farm activities yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Start recording farm operations and events.',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToCreateActivity(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Record First Activity'),
                      ),
                    ],
                  ),
                )
              : ActivityFeedWidget(
                  activities: feedItems,
                  emptyTitle: 'No farm activities yet',
                  emptySubtitle: 'Start recording farm operations and events.',
                ),
                ),
      ],
    ),
    );
  }

        void _navigateToCreateActivity(BuildContext context) {
      // Auto-pass hierarchy context to the creation page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ActivityCreationPage(),
        ),
      );
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