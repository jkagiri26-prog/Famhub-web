/// ============================================================
/// AGRI CONNECT — COMMUNITY INVITATION ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`community_invitations`)
///
/// Recipient is exactly one of `invitedProfileId` OR `invitedEmail` — never both.
/// ============================================================
library;

import '../enums/community_enums.dart';

class CommunityInvitation {
  final String id;
  final String communityId;
  final String? invitedProfileId;
  final String? invitedEmail;
  final String invitedBy;
  final InvitationStatus status;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime createdAt;

  const CommunityInvitation({
    required this.id,
    required this.communityId,
    this.invitedProfileId,
    this.invitedEmail,
    required this.invitedBy,
    this.status = InvitationStatus.pending,
    this.expiresAt,
    this.acceptedAt,
    required this.createdAt,
  });

  factory CommunityInvitation.fromJson(Map<String, dynamic> json) {
    return CommunityInvitation(
      id: json['id']?.toString() ?? '',
      communityId: json['community_id']?.toString() ?? '',
      invitedProfileId: json['invited_profile_id']?.toString(),
      invitedEmail: json['invited_email']?.toString(),
      invitedBy: json['invited_by']?.toString() ?? '',
      status: InvitationStatus.fromValue(json['status']?.toString()),
      expiresAt: _parse(json['expires_at']),
      acceptedAt: _parse(json['accepted_at']),
      createdAt:
          _parse(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
