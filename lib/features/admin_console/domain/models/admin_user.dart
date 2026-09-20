/// ============================================================
/// ADMIN USER — READ MODEL (presentation DTO)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/domain/models/ = domain models
///
/// A read-only projection returned by the admin-safe RPC
/// `users.admin_list_users`. It intentionally contains ONLY the fields the
/// backend exposes for platform administration — no auth/OTP/token fields
/// and no `user_type` (not deployed).
///
/// This is a presentation-specific DTO for the admin directory; it does not
/// duplicate the canonical session profile model.
/// ============================================================
library;

class AdminUser {
  final String profileId;
  final String displayName;
  final String? email;
  final String? phone;
  final bool isActive;
  final String? accountStatus;
  final String? profileStatus;
  final bool isComplete;
  final bool verified;
  final DateTime? createdAt;
  final int workspaceCount;
  final String? defaultWorkspaceId;
  final String? defaultWorkspaceName;
  final int entityCount;

  const AdminUser({
    required this.profileId,
    required this.displayName,
    this.email,
    this.phone,
    this.isActive = false,
    this.accountStatus,
    this.profileStatus,
    this.isComplete = false,
    this.verified = false,
    this.createdAt,
    this.workspaceCount = 0,
    this.defaultWorkspaceId,
    this.defaultWorkspaceName,
    this.entityCount = 0,
  });

  factory AdminUser.fromMap(Map<String, dynamic> map) {
    return AdminUser(
      profileId: map['profile_id']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? '',
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      isActive: map['is_active'] == true,
      accountStatus: map['account_status']?.toString(),
      profileStatus: map['profile_status']?.toString(),
      isComplete: map['is_complete'] == true,
      verified: map['verified'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
      workspaceCount: (map['workspace_count'] as num?)?.toInt() ?? 0,
      defaultWorkspaceId: map['default_workspace_id']?.toString(),
      defaultWorkspaceName: map['default_workspace_name']?.toString(),
      entityCount: (map['entity_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One page of the admin user directory (`total_count` comes from the RPC).
class AdminUsersPage {
  final List<AdminUser> items;
  final int totalCount;

  const AdminUsersPage({required this.items, required this.totalCount});

  factory AdminUsersPage.empty() =>
      const AdminUsersPage(items: [], totalCount: 0);

  bool get isEmpty => items.isEmpty;
}
