/// ============================================================
/// AGRI CONNECT — COMMUNITY ENUMS
/// ============================================================
///
/// Value strings map exactly to the `agri_connect` CHECK constraints.
/// Source: docs/Backend schemas/agri_connect.md
/// ============================================================
library;

/// `agri_connect.communities.community_type`
enum CommunityType {
  interest,
  location,
  buyer,
  selfHelp('self_help'),
  cooperative,
  organization,
  private,
  project;

  const CommunityType([this.value]);

  final String? value;

  String get dbValue => value ?? name;

  static CommunityType fromValue(String? v) => CommunityType.values.firstWhere(
    (e) => e.dbValue == v,
    orElse: () => CommunityType.interest,
  );
}

/// `agri_connect.communities.visibility`
enum CommunityVisibility {
  public,
  private,
  restricted;

  static CommunityVisibility fromValue(String? v) => CommunityVisibility.values
      .firstWhere((e) => e.name == v, orElse: () => CommunityVisibility.public);
}

/// `agri_connect.community_members.role`
enum MemberRole {
  member,
  moderator,
  admin,
  owner;

  static MemberRole fromValue(String? v) => MemberRole.values.firstWhere(
    (e) => e.name == v,
    orElse: () => MemberRole.member,
  );

  bool get canModerate => this == MemberRole.admin || this == MemberRole.owner;

  bool get canManageRules =>
      this == MemberRole.admin || this == MemberRole.owner;
}

/// `agri_connect.community_members.status`
enum MemberStatus {
  pending,
  active,
  suspended,
  banned,
  left,
  rejected;

  static MemberStatus fromValue(String? v) => MemberStatus.values.firstWhere(
    (e) => e.name == v,
    orElse: () => MemberStatus.active,
  );
}

/// `agri_connect.community_join_requests.status`
enum JoinRequestStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static JoinRequestStatus fromValue(String? v) => JoinRequestStatus.values
      .firstWhere((e) => e.name == v, orElse: () => JoinRequestStatus.pending);
}

/// `agri_connect.community_invitations.status`
enum InvitationStatus {
  pending,
  accepted,
  declined,
  expired,
  cancelled;

  static InvitationStatus fromValue(String? v) => InvitationStatus.values
      .firstWhere((e) => e.name == v, orElse: () => InvitationStatus.pending);
}
