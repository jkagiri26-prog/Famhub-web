/// ============================================================
/// AGRI CONNECT — MESSAGING ENUMS
/// ============================================================
/// Source: docs/Backend schemas/agri_connect.md
/// ============================================================
library;

/// `agri_connect.conversations.conversation_type`
enum ConversationType {
  direct,
  group,
  community,
  marketplace,
  support,
  organization;

  static ConversationType fromValue(String? v) => ConversationType.values
      .firstWhere((e) => e.name == v, orElse: () => ConversationType.direct);
}

/// `agri_connect.conversation_participants.role`
enum ParticipantRole {
  participant,
  moderator,
  admin,
  owner;

  static ParticipantRole fromValue(String? v) =>
      ParticipantRole.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ParticipantRole.participant,
      );

  bool get canModerate =>
      this == ParticipantRole.moderator ||
      this == ParticipantRole.admin ||
      this == ParticipantRole.owner;
}

/// `agri_connect.conversation_participants.status`
enum ParticipantStatus {
  invited,
  active,
  left,
  removed,
  blocked;

  static ParticipantStatus fromValue(String? v) => ParticipantStatus.values
      .firstWhere((e) => e.name == v, orElse: () => ParticipantStatus.active);
}

/// `agri_connect.messages.message_type`
enum MessageType {
  text,
  image,
  video,
  document,
  audio,
  system;

  static MessageType fromValue(String? v) => MessageType.values.firstWhere(
    (e) => e.name == v,
    orElse: () => MessageType.text,
  );

  bool get isMedia =>
      this == MessageType.image ||
      this == MessageType.video ||
      this == MessageType.document ||
      this == MessageType.audio;
}
