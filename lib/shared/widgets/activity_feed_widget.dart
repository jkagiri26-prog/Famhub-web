/// ============================================================
/// ACTIVITY FEED WIDGET (REUSABLE ACTIVITY LIST)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/widgets/ = reusable presentation widgets
///
/// ✅ Responsibilities:
///   - Consistent activity/timeline feed
///   - Reusable across all modules
///   - Loading/empty states built-in
///
/// ❌ Does NOT:
///   - Reference registry, services, or providers
///   - Contain business logic
/// ============================================================

import 'package:flutter/material.dart';

class ActivityFeedWidget extends StatelessWidget {
  final List<ActivityItem> activities;
  final bool isLoading;
  final String? emptyTitle;
  final String? emptySubtitle;

  const ActivityFeedWidget({
    super.key,
    required this.activities,
    this.isLoading = false,
    this.emptyTitle,
    this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoading(context);
    }

    if (activities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history_rounded,
                size: 40,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                emptyTitle ?? 'No recent activity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              if (emptySubtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  emptySubtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityTile(context, activity);
      },
    );
  }

  Widget _buildActivityTile(BuildContext context, ActivityItem activity) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: activity.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          activity.icon,
          size: 18,
          color: activity.color,
        ),
      ),
      title: Text(
        activity.title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: activity.subtitle != null
          ? Text(
              activity.subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            )
          : null,
      trailing: activity.timestamp != null
          ? Text(
              activity.timestamp!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            )
          : null,
      dense: true,
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class ActivityItem {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String? timestamp;

  const ActivityItem({
    required this.title,
    this.subtitle,
    required this.icon,
    this.color = Colors.blue,
    this.timestamp,
  });
}
