/// ============================================================
/// AGRI CONNECT — CONVERSATION PARTICIPANT ENTITY
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md (`conversation_participants`)
///
/// Each participant row uses exactly one identity: `profileId` OR `entityId`.
/// ============================================================
library;

import '../enums/messaging_enums.dart';

class ConversationParticipant {
  final String id;
  final String conversationId;
  final String? profileId;
  final String? entityId;
  final ParticipantRole role;
  final ParticipantStatus status;
  final DateTime? joinedAt;
  final DateTime? lastReadAt;
  final DateTime? mutedUntil;
  final DateTime createdAt;

  /// Resolved at query time (display name of the profile/entity).
  final String? displayName;

  const ConversationParticipant({
    required this.id,
    required this.conversationId,
    this.profileId,
    this.entityId,
    this.role = ParticipantRole.participant,
    this.status = ParticipantStatus.active,
    this.joinedAt,
    this.lastReadAt,
    this.mutedUntil,
    required this.createdAt,
    this.displayName,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) {
    return ConversationParticipant(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      profileId: json['profile_id']?.toString(),
      entityId: json['entity_id']?.toString(),
      role: ParticipantRole.fromValue(json['role']?.toString()),
      status: ParticipantStatus.fromValue(json['status']?.toString()),
      joinedAt: _parse(json['joined_at']),
      lastReadAt: _parse(json['last_read_at']),
      mutedUntil: _parse(json['muted_until']),
      createdAt:
          _parse(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      displayName: json['display_name']?.toString(),
    );
  }

  bool get isActive => status == ParticipantStatus.active;

  static DateTime? _parse(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
}
