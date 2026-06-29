// ignore: dangling_library_doc_comments
/// ============================================================
/// DASHBOARD ACTIVITY FEED — LIVE PROVIDER WIDGET
/// ============================================================
///
/// ✅ CONSUMES:
///   - farmDashboardProvider (existing async provider)
///
/// ✅ RESPONSIBILITIES:
///   - Show recent farmer activities
///   - Connect to real data from repository
///   - Render using shared ActivityFeedWidget
/// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'package:famhub_app/shared/widgets/activity_feed_widget.dart';

class DashboardActivityFeed extends ConsumerWidget {
  const DashboardActivityFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(farmDashboardProvider);

    return dashboardAsync.when(
      loading: () => _buildSkeleton(),
      error: (e, _) => _buildError(context, e.toString()),
      data: (data) {
        final activities = data.todayActivities;

        final items = activities.map((a) {
          return ActivityItem(
            title: 'Activity completed',
            subtitle: a.notes ?? 'Recorded activity',
            icon: Icons.check_circle_outline_rounded,
            color: Colors.green,
            timestamp: _formatTime(a.performedAt),
          );
        }).toList();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      size: 18,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ActivityFeedWidget(
                activities: items,
                emptyTitle: 'No recent activity',
                emptySubtitle: 'Complete your first farm activity to see it here',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeleton() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
