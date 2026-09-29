/// ============================================================
/// AGRI CONNECT — MESSAGING PROVIDERS
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/conversation.dart';
import '../../domain/entities/conversation_participant.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/reaction_summary.dart';
import '../../domain/enums/messaging_enums.dart';
import '../../domain/repositories/messaging_repository.dart';
import 'agri_connect_providers.dart';

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final profileId = ref.watch(agriConnectProfileIdProvider);
  if (profileId == null) return const [];
  return ref.watch(messagingRepositoryProvider).fetchConversations(profileId);
});

final conversationDetailsProvider =
    FutureProvider.family<Conversation?, String>((ref, conversationId) async {
      return ref
          .watch(messagingRepositoryProvider)
          .fetchConversationById(conversationId);
    });

final participantsProvider =
    FutureProvider.family<List<ConversationParticipant>, String>((
      ref,
      conversationId,
    ) async {
      return ref
          .watch(messagingRepositoryProvider)
          .fetchParticipants(conversationId);
    });

final messagesProvider = FutureProvider.family<List<Message>, String>((
  ref,
  conversationId,
) async {
  return ref
      .watch(messagingRepositoryProvider)
      .fetchMessages(conversationId: conversationId);
});

final messageReactionsProvider = FutureProvider.family<ReactionSummary, String>(
  (ref, messageId) async {
    final profileId = ref.watch(agriConnectProfileIdProvider) ?? '';
    return ref
        .watch(messagingRepositoryProvider)
        .fetchMessageReactions(messageId: messageId, profileId: profileId);
  },
);

/// Mutation controller for conversations, participants and messages.
class MessagingController extends Notifier<void> {
  MessagingRepository get _repo => ref.read(messagingRepositoryProvider);

  @override
  void build() {}

  Future<Conversation> createConversation({
    required ConversationType type,
    String? title,
    String? communityId,
  }) async {
    final conversation = await _repo.createConversation(
      type: type,
      title: title,
      communityId: communityId,
    );
    ref.invalidate(conversationsProvider);
    return conversation;
  }

  Future<void> addParticipant({
    required String conversationId,
    required String profileId,
  }) async {
    await _repo.addParticipant(
      conversationId: conversationId,
      profileId: profileId,
    );
    ref.invalidate(participantsProvider(conversationId));
  }

  Future<Message> sendMessage({
    required String conversationId,
    MessageType type = MessageType.text,
    String? body,
    String? replyToMessageId,
    String? mediaFileId,
  }) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) {
      throw Exception('You must be signed in to send messages.');
    }
    final message = await _repo.sendMessage(
      conversationId: conversationId,
      senderProfileId: profileId,
      type: type,
      body: body,
      replyToMessageId: replyToMessageId,
      mediaFileId: mediaFileId,
    );
    ref.invalidate(messagesProvider(conversationId));
    ref.invalidate(conversationsProvider);
    return message;
  }

  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String body,
  }) async {
    await _repo.editMessage(messageId: messageId, body: body);
    ref.invalidate(messagesProvider(conversationId));
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _repo.deleteMessage(messageId);
    ref.invalidate(messagesProvider(conversationId));
    ref.invalidate(conversationsProvider);
  }

  Future<void> react({
    required String messageId,
    required String reaction,
  }) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) {
      throw Exception('You must be signed in to react.');
    }
    await _repo.setMessageReaction(
      messageId: messageId,
      profileId: profileId,
      reaction: reaction,
    );
    ref.invalidate(messageReactionsProvider(messageId));
  }

  Future<void> removeReaction(String messageId) async {
    final profileId = ref.read(agriConnectProfileIdProvider);
    if (profileId == null) return;
    await _repo.removeMessageReaction(
      messageId: messageId,
      profileId: profileId,
    );
    ref.invalidate(messageReactionsProvider(messageId));
  }
}

final messagingControllerProvider = NotifierProvider<MessagingController, void>(
  MessagingController.new,
);
