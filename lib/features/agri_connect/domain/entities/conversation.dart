/// ============================================================
/// AGRI CONNECT — CONVERSATION ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`conversations`)
///
/// `last_message_at` is database-maintained — never written by the client.
/// ============================================================
library;

import '../enums/messaging_enums.dart';

class Conversation {
  final String id;
  final ConversationType type;
  final String? title;
  final String? communityId;
  final String? createdBy;
  final String? contextType;
  final String? contextId;
  final bool isActive;
  final DateTime? lastMessageAt;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    required this.type,
    this.title,
    this.communityId,
    this.createdBy,
    this.contextType,
    this.contextId,
    this.isActive = true,
    this.lastMessageAt,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id']?.toString() ?? '',
      type: ConversationType.fromValue(json['conversation_type']?.toString()),
      title: json['title']?.toString(),
      communityId: json['community_id']?.toString(),
      createdBy: json['created_by']?.toString(),
      contextType: json['context_type']?.toString(),
      contextId: json['context_id']?.toString(),
      isActive: json['is_active'] == true,
      lastMessageAt: _parse(json['last_message_at']),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      createdAt:
          _parse(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _parse(json['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
