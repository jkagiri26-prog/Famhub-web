/// ============================================================
/// BUSINESS MEMBER (DOMAIN)
/// ============================================================
///
/// Read model for ONE membership row of `core.entity_members`.
///
/// Actual documented columns (docs/Backend schemas/core schema.md):
///   id, entity_id, profile_id (→ users.profiles), role_id
///   (→ core.user_roles), assigned_at, is_active, can_sell, can_manage,
///   can_receive_payments, membership_status
///
/// Read-only for this phase: no invitations, role changes or permission
/// editing are exposed. Only rows the current user is authorized to see
/// are returned (RLS).
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class BusinessMember {
  /// FK → users.profiles.
  final String profileId;

  /// FK → core.user_roles (nullable).
  final String? roleId;

  /// Resolved role name (core.user_roles.name).
  final String? roleName;

  /// Resolved member display name (users.profiles first/last name).
  final String? displayName;

  final bool canSell;
  final bool canManage;
  final bool canReceivePayments;

  /// Raw membership_status: pending | active | suspended | revoked.
  final String membershipStatus;

  const BusinessMember({
    required this.profileId,
    this.roleId,
    this.roleName,
    this.displayName,
    this.canSell = false,
    this.canManage = false,
    this.canReceivePayments = false,
    this.membershipStatus = 'active',
  });

  bool get isActive => membershipStatus == 'active';

  /// Member label: resolved name with a sensible fallback.
  String get label =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!.trim()
          : 'Team member';
}
