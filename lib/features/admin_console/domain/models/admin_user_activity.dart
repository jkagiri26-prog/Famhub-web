/// ============================================================
/// ADMIN USER ACTIVITY — READ MODEL (presentation DTO)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/domain/models/ = domain models
///
/// A read-only projection returned by the admin-safe RPC
/// `users.admin_list_user_activity`. Contains ONLY the fields the backend
/// exposes — no raw audit payloads, IP addresses, tokens or auth metadata.
///
/// `entity_id`/`entity_name`/`workspace_id`/`workspace_name`/`status` are
/// intentionally null for this source; they are never reconstructed
/// client-side.
/// ============================================================
library;

class AdminUserActivity {
  final String activityId;
  final String profileId;
  final String? displayName;
  final String? eventType;
  final String? description;
  final String? entityId;
  final String? entityName;
  final String? workspaceId;
  final String? workspaceName;
  final String? status;
  final DateTime? occurredAt;

  const AdminUserActivity({
    required this.activityId,
    required this.profileId,
    this.displayName,
    this.eventType,
    this.description,
    this.entityId,
    this.entityName,
    this.workspaceId,
    this.workspaceName,
    this.status,
    this.occurredAt,
  });

  factory AdminUserActivity.fromMap(Map<String, dynamic> map) {
    return AdminUserActivity(
      activityId: map['activity_id']?.toString() ?? '',
      profileId: map['profile_id']?.toString() ?? '',
      displayName: map['display_name']?.toString(),
      eventType: map['event_type']?.toString(),
      description: map['description']?.toString(),
      entityId: map['entity_id']?.toString(),
      entityName: map['entity_name']?.toString(),
      workspaceId: map['workspace_id']?.toString(),
      workspaceName: map['workspace_name']?.toString(),
      status: map['status']?.toString(),
      occurredAt: DateTime.tryParse(map['occurred_at']?.toString() ?? ''),
    );
  }
}

/// One page of the admin user activity feed (`total_count` from the RPC).
class AdminUserActivityPage {
  final List<AdminUserActivity> items;
  final int totalCount;

  const AdminUserActivityPage({
    required this.items,
    required this.totalCount,
  });

  factory AdminUserActivityPage.empty() =>
      const AdminUserActivityPage(items: [], totalCount: 0);

  bool get isEmpty => items.isEmpty;
}
