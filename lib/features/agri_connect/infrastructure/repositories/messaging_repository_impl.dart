/// ============================================================
/// AGRI CONNECT — MESSAGING REPOSITORY IMPLEMENTATION
/// ============================================================
library;

import 'package:famhub_app/features/agri_connect/domain/entities/conversation.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/conversation_participant.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/message.dart';
import 'package:famhub_app/features/agri_connect/domain/entities/reaction_summary.dart';
import 'package:famhub_app/features/agri_connect/domain/enums/messaging_enums.dart';
import 'package:famhub_app/features/agri_connect/domain/repositories/messaging_repository.dart';
import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/agri_connect_profile_names.dart';
import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/messaging_remote_data_source.dart';

class MessagingRepositoryImpl implements MessagingRepository {
  final MessagingRemoteDataSource _dataSource;
  final AgriConnectProfileNames _profileNames;

  MessagingRepositoryImpl(this._dataSource, this._profileNames);

  @override
  Future<List<Conversation>> fetchConversations(String profileId) async {
    final ids = await _dataSource.fetchConversationIds(profileId);
    final rows = await _dataSource.fetchConversationsByIds(ids);
    return rows.map(Conversation.fromJson).toList();
  }

  @override
  Future<Conversation?> fetchConversationById(String conversationId) async {
    final row = await _dataSource.fetchConversationById(conversationId);
    return row == null ? null : Conversation.fromJson(row);
  }

  @override
  Future<Conversation> createConversation({
    required ConversationType type,
    String? title,
    String? communityId,
  }) async {
    final row = await _dataSource.createConversation(
      type: type.name,
      title: title,
      communityId: communityId,
    );
    if (row != null) return Conversation.fromJson(row);
    throw Exception('Conversation was created but could not be loaded.');
  }

  @override
  Future<List<ConversationParticipant>> fetchParticipants(
    String conversationId,
  ) async {
    final rows = await _dataSource.fetchParticipants(conversationId);
    final profileIds = rows
        .map((r) => r['profile_id']?.toString() ?? '')
        .toSet();
    final names = await _profileNames.resolve(profileIds);
    return rows.map((r) {
      final map = Map<String, dynamic>.from(r);
      final pid = map['profile_id']?.toString();
      if (pid != null && names.containsKey(pid)) {
        map['display_name'] = names[pid];
      }
      return ConversationParticipant.fromJson(map);
    }).toList();
  }

  @override
  Future<void> addParticipant({
    required String conversationId,
    required String profileId,
    ParticipantRole role = ParticipantRole.participant,
  }) async {
    await _dataSource.addParticipant(
      conversationId: conversationId,
      profileId: profileId,
      role: role.name,
    );
  }

  @override
  Future<void> removeParticipant({
    required String conversationId,
    required String profileId,
  }) async {
    await _dataSource.removeParticipant(
      conversationId: conversationId,
      profileId: profileId,
    );
  }

  @override
  Future<List<Message>> fetchMessages({
    required String conversationId,
    int limit = 100,
  }) async {
    final rows = await _dataSource.fetchMessages(
      conversationId: conversationId,
      limit: limit,
    );
    return rows.map(Message.fromJson).toList();
  }

  @override
  Future<Message> sendMessage({
    required String conversationId,
    required String senderProfileId,
    MessageType type = MessageType.text,
    String? body,
    String? replyToMessageId,
    String? mediaFileId,
  }) async {
    final row = await _dataSource.insertMessage({
      'conversation_id': conversationId,
      'sender_profile_id': senderProfileId,
      'message_type': type.name,
      if (body != null && body.isNotEmpty) 'body': body,
      if (replyToMessageId != null && replyToMessageId.isNotEmpty)
        'reply_to_message_id': replyToMessageId,
      if (mediaFileId != null && mediaFileId.isNotEmpty)
        'media_file_id': mediaFileId,
    });
    return Message.fromJson(row);
  }

  @override
  Future<Message> editMessage({
    required String messageId,
    required String body,
  }) async {
    final row = await _dataSource.editMessage(messageId: messageId, body: body);
    return Message.fromJson(row);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    await _dataSource.deleteMessage(messageId);
  }

  @override
  Future<ReactionSummary> fetchMessageReactions({
    required String messageId,
    required String profileId,
  }) async {
    final rows = await _dataSource.fetchMessageReactions(messageId);
    final counts = <String, int>{};
    String? mine;
    for (final row in rows) {
      final reaction = row['reaction']?.toString() ?? '';
      final pid = row['profile_id']?.toString() ?? '';
      if (reaction.isEmpty) continue;
      counts[reaction] = (counts[reaction] ?? 0) + 1;
      if (pid == profileId) mine = reaction;
    }
    return ReactionSummary(counts: counts, myReaction: mine);
  }

  @override
  Future<void> setMessageReaction({
    required String messageId,
    required String profileId,
    required String reaction,
  }) async {
    await _dataSource.upsertMessageReaction(
      messageId: messageId,
      profileId: profileId,
      reaction: reaction,
    );
  }

  @override
  Future<void> removeMessageReaction({
    required String messageId,
    required String profileId,
  }) async {
    await _dataSource.removeMessageReaction(
      messageId: messageId,
      profileId: profileId,
    );
  }
}
