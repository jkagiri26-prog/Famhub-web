/// ============================================================
/// AGRI CONNECT — DISCUSSION ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`discussions`)
///
/// `view_count` and `reply_count` are database-maintained — never written.
/// ============================================================
library;

import '../enums/discussion_enums.dart';

class Discussion {
  final String id;
  final String? communityId;
  final String title;
  final DiscussionType type;
  final String createdBy;
  final bool isPinned;
  final bool isLocked;
  final bool isActive;
  final int viewCount;
  final int replyCount;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Discussion({
    required this.id,
    this.communityId,
    required this.title,
    this.type = DiscussionType.discussion,
    required this.createdBy,
    this.isPinned = false,
    this.isLocked = false,
    this.isActive = true,
    this.viewCount = 0,
    this.replyCount = 0,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Discussion.fromJson(Map<String, dynamic> json) {
    return Discussion(
      id: json['id']?.toString() ?? '',
      communityId: json['community_id']?.toString(),
      title: json['title']?.toString() ?? '',
      type: DiscussionType.fromValue(json['discussion_type']?.toString()),
      createdBy: json['created_by']?.toString() ?? '',
      isPinned: json['is_pinned'] == true,
      isLocked: json['is_locked'] == true,
      isActive: json['is_active'] == true,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
