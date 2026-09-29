/// ============================================================
/// AGRI CONNECT — COMMUNITY JOIN REQUEST ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`community_join_requests`)
/// ============================================================
library;

import '../enums/community_enums.dart';

class CommunityJoinRequest {
  final String id;
  final String communityId;
  final String profileId;
  final JoinRequestStatus status;
  final String? message;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const CommunityJoinRequest({
    required this.id,
    required this.communityId,
    required this.profileId,
    this.status = JoinRequestStatus.pending,
    this.message,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
  });

  factory CommunityJoinRequest.fromJson(Map<String, dynamic> json) {
    return CommunityJoinRequest(
      id: json['id']?.toString() ?? '',
      communityId: json['community_id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      status: JoinRequestStatus.fromValue(json['status']?.toString()),
      message: json['message']?.toString(),
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: _parse(json['reviewed_at']),
      createdAt:
          _parse(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
