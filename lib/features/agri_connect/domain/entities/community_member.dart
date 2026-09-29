/// ============================================================
/// AGRI CONNECT — COMMUNITY MEMBER ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`community_members`)
/// ============================================================
library;

import '../enums/community_enums.dart';

class CommunityMember {
  final String id;
  final String communityId;
  final String profileId;
  final MemberRole role;
  final MemberStatus status;
  final DateTime? joinedAt;
  final String? invitedBy;
  final DateTime? requestedAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? mutedUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Resolved at query time (member display name).
  final String? displayName;

  const CommunityMember({
    required this.id,
    required this.communityId,
    required this.profileId,
    this.role = MemberRole.member,
    this.status = MemberStatus.active,
    this.joinedAt,
    this.invitedBy,
    this.requestedAt,
    this.approvedBy,
    this.approvedAt,
    this.mutedUntil,
    required this.createdAt,
    required this.updatedAt,
    this.displayName,
  });

  factory CommunityMember.fromJson(Map<String, dynamic> json) {
    return CommunityMember(
      id: json['id']?.toString() ?? '',
      communityId: json['community_id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      role: MemberRole.fromValue(json['role']?.toString()),
      status: MemberStatus.fromValue(json['status']?.toString()),
      joinedAt: _parse(json['joined_at']),
      invitedBy: json['invited_by']?.toString(),
      requestedAt: _parse(json['requested_at']),
      approvedBy: json['approved_by']?.toString(),
      approvedAt: _parse(json['approved_at']),
      mutedUntil: _parse(json['muted_until']),
      createdAt:
          _parse(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parse(json['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      displayName: json['display_name']?.toString(),
    );
  }

  bool get isActive => status == MemberStatus.active;

  bool get canModerate => role.canModerate;

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
