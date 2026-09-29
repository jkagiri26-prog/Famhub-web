/// ============================================================
/// AGRI CONNECT — MESSAGING REPOSITORY CONTRACT
/// ============================================================
///
/// Conversations, participants, messages and reactions.
/// `last_message_at` is database-maintained — never written.
/// ============================================================
library;

import '../entities/conversation.dart';
import '../entities/conversation_participant.dart';
import '../entities/message.dart';
import '../entities/reaction_summary.dart';
import '../enums/messaging_enums.dart';

abstract class MessagingRepository {
  /// Conversations the caller participates in.
  Future<List<Conversation>> fetchConversations(String profileId);

  Future<Conversation?> fetchConversationById(String conversationId);

  /// Create a conversation via `agri_connect.create_conversation`.
  ///
  /// Only `type`, `title` and `communityId` are sent for normal Agri Connect
  /// conversations — `context_type`/`context_id` are always omitted.
  Future<Conversation> createConversation({
    required ConversationType type,
    String? title,
    String? communityId,
  });

  // ── Participants ───────────────────────────────────────────
  Future<List<ConversationParticipant>> fetchParticipants(
    String conversationId,
  );

  Future<void> addParticipant({
    required String conversationId,
    required String profileId,
    ParticipantRole role = ParticipantRole.participant,
  });

  Future<void> removeParticipant({
    required String conversationId,
    required String profileId,
  });

  // ── Messages ───────────────────────────────────────────────
  Future<List<Message>> fetchMessages({
    required String conversationId,
    int limit = 100,
  });

  Future<Message> sendMessage({
    required String conversationId,
    required String senderProfileId,
    MessageType type = MessageType.text,
    String? body,
    String? replyToMessageId,
    String? mediaFileId,
  });

  Future<Message> editMessage({
    required String messageId,
    required String body,
  });

  Future<void> deleteMessage(String messageId);

  // ── Message reactions (UPSERT: one per user per message) ───
  Future<ReactionSummary> fetchMessageReactions({
    required String messageId,
    required String profileId,
  });

  Future<void> setMessageReaction({
    required String messageId,
    required String profileId,
    required String reaction,
  });

  Future<void> removeMessageReaction({
    required String messageId,
    required String profileId,
  });
}
