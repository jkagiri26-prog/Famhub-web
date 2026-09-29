/// ============================================================
/// AGRI CONNECT — MESSAGE ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`messages`)
///
/// The sender identity is backend-enforced (`senderProfileId` OR
/// `senderEntityId`). The client never impersonates a sender.
/// ============================================================
library;

import '../enums/messaging_enums.dart';

class Message {
  final String id;
  final String conversationId;
  final String? senderProfileId;
  final String? senderEntityId;
  final MessageType type;
  final String? body;
  final String? replyToMessageId;
  final String? mediaFileId;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;

  /// Emoji → count, resolved at query time.
  final Map<String, int> reactionCounts;

  /// Current user's reaction on this message (null when none).
  final String? myReaction;

  const Message({
    required this.id,
    required this.conversationId,
    this.senderProfileId,
    this.senderEntityId,
    this.type = MessageType.text,
    this.body,
    this.replyToMessageId,
    this.mediaFileId,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    this.reactionCounts = const {},
    this.myReaction,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      senderProfileId: json['sender_profile_id']?.toString(),
      senderEntityId: json['sender_entity_id']?.toString(),
      type: MessageType.fromValue(json['message_type']?.toString()),
      body: json['body']?.toString(),
      replyToMessageId: json['reply_to_message_id']?.toString(),
      mediaFileId: json['media_file_id']?.toString(),
      isEdited: json['is_edited'] == true,
      editedAt: _parse(json['edited_at']),
      isDeleted: json['is_deleted'] == true,
      deletedAt: _parse(json['deleted_at']),
      createdAt:
          _parse(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      reactionCounts: _reactionCounts(json['reaction_counts']),
      myReaction: json['my_reaction']?.toString(),
    );
  }

  static Map<String, int> _reactionCounts(dynamic v) {
    if (v is Map) {
      return v.map(
        (k, val) => MapEntry(k.toString(), (val is num) ? val.toInt() : 0),
      );
    }
    return const {};
  }

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
