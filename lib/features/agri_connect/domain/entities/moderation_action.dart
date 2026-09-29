/// ============================================================
/// AGRI CONNECT — MODERATION ACTION ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`moderation_actions`)
/// ============================================================
library;

import '../enums/safety_enums.dart';

class ModerationAction {
  final String id;
  final String? communityId;
  final String moderatorProfileId;
  final String targetType;
  final String targetId;
  final ModerationActionType actionType;
  final String? reason;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const ModerationAction({
    required this.id,
    this.communityId,
    required this.moderatorProfileId,
    required this.targetType,
    required this.targetId,
    required this.actionType,
    this.reason,
    this.metadata = const {},
    required this.createdAt,
  });

  factory ModerationAction.fromJson(Map<String, dynamic> json) {
    return ModerationAction(
      id: json['id']?.toString() ?? '',
      communityId: json['community_id']?.toString(),
      moderatorProfileId: json['moderator_profile_id']?.toString() ?? '',
      targetType: json['target_type']?.toString() ?? '',
      targetId: json['target_id']?.toString() ?? '',
      actionType: ModerationActionType.fromValue(
        json['action_type']?.toString(),
      ),
      reason: json['reason']?.toString(),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
