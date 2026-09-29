/// ============================================================
/// AGRI CONNECT — MESSAGING REMOTE DATA SOURCE
/// ============================================================
///
/// Raw Supabase operations for conversations, participants, messages
/// and message reactions. Creation goes through `create_conversation`
/// RPC. `last_message_at` is database-maintained — never written.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class MessagingRemoteDataSource {
  final SupabaseClient _client;

  MessagingRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _schema = 'agri_connect';

  static const String _conversationSelect = '''
    id, conversation_type, title, community_id, created_by, context_type,
    context_id, is_active, last_message_at, metadata, created_at, updated_at
  ''';

  static const String _messageSelect = '''
    id, conversation_id, sender_profile_id, sender_entity_id, message_type,
    body, reply_to_message_id, media_file_id, is_edited, edited_at, is_deleted,
    deleted_at, created_at
  ''';

  // ── Conversations ──────────────────────────────────────────

  Future<List<String>> fetchConversationIds(String profileId) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('conversation_participants')
          .select('conversation_id')
          .eq('profile_id', profileId)
          .eq('status', 'active');
      return (response as List)
          .map((r) => (r as Map)['conversation_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load conversations: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load conversations: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchConversationsByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    try {
      final response = await _client
          .schema(_schema)
          .from('conversations')
          .select(_conversationSelect)
          .inFilter('id', ids)
          .order('last_message_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load conversations: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load conversations: $e');
    }
  }

  Future<Map<String, dynamic>?> fetchConversationById(
    String conversationId,
  ) async {
    try {
      return await _client
          .schema(_schema)
          .from('conversations')
          .select(_conversationSelect)
          .eq('id', conversationId)
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load conversation: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load conversation: $e');
    }
  }

  /// Creates a conversation via `agri_connect.create_conversation`.
  Future<Map<String, dynamic>?> createConversation({
    required String type,
    String? title,
    String? communityId,
  }) async {
    final response = await _client
        .schema(_schema)
        .rpc(
          'create_conversation',
          params: {
            'p_conversation_type': type,
            if (title != null && title.trim().isNotEmpty)
              'p_title': title.trim(),
            if (communityId != null && communityId.isNotEmpty)
              'p_community_id': communityId,
          },
        );
    return _firstRow(response);
  }

  // ── Participants ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchParticipants(
    String conversationId,
  ) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('conversation_participants')
          .select()
          .eq('conversation_id', conversationId)
          .eq('status', 'active');
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load participants: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load participants: $e');
    }
  }

  Future<void> addParticipant({
    required String conversationId,
    required String profileId,
    String role = 'participant',
  }) async {
    try {
      await _client.schema(_schema).from('conversation_participants').insert({
        'conversation_id': conversationId,
        'profile_id': profileId,
        'role': role,
        'status': 'active',
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to add participant: ${e.message}');
    } catch (e) {
      throw Exception('Failed to add participant: $e');
    }
  }

  Future<void> removeParticipant({
    required String conversationId,
    required String profileId,
  }) async {
    try {
      await _client
          .schema(_schema)
          .from('conversation_participants')
          .update({'status': 'left'})
          .eq('conversation_id', conversationId)
          .eq('profile_id', profileId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to remove participant: ${e.message}');
    } catch (e) {
      throw Exception('Failed to remove participant: $e');
    }
  }

  // ── Messages ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMessages({
    required String conversationId,
    int limit = 100,
  }) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('messages')
          .select(_messageSelect)
          .eq('conversation_id', conversationId)
          .eq('is_deleted', false)
          .order('created_at', ascending: true)
          .limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load messages: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load messages: $e');
    }
  }

  Future<Map<String, dynamic>> insertMessage(Map<String, dynamic> data) async {
    try {
      return await _client
          .schema(_schema)
          .from('messages')
          .insert(data)
          .select(_messageSelect)
          .single();
    } on PostgrestException catch (e) {
      throw Exception('Failed to send message: ${e.message}');
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String body,
  }) async {
    try {
      return await _client
          .schema(_schema)
          .from('messages')
          .update({
            'body': body,
            'is_edited': true,
            'edited_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .select(_messageSelect)
          .single();
    } on PostgrestException catch (e) {
      throw Exception('Failed to edit message: ${e.message}');
    } catch (e) {
      throw Exception('Failed to edit message: $e');
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _client
          .schema(_schema)
          .from('messages')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete message: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete message: $e');
    }
  }

  // ── Message reactions (UPSERT) ─────────────────────────────

  Future<List<Map<String, dynamic>>> fetchMessageReactions(
    String messageId,
  ) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('message_reactions')
          .select('profile_id, reaction')
          .eq('message_id', messageId);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load reactions: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load reactions: $e');
    }
  }

  Future<void> upsertMessageReaction({
    required String messageId,
    required String profileId,
    required String reaction,
  }) async {
    try {
      await _client.schema(_schema).from('message_reactions').upsert({
        'message_id': messageId,
        'profile_id': profileId,
        'reaction': reaction,
      }, onConflict: 'message_id,profile_id');
    } on PostgrestException catch (e) {
      throw Exception('Failed to react: ${e.message}');
    } catch (e) {
      throw Exception('Failed to react: $e');
    }
  }

  Future<void> removeMessageReaction({
    required String messageId,
    required String profileId,
  }) async {
    try {
      await _client
          .schema(_schema)
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('profile_id', profileId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to remove reaction: ${e.message}');
    } catch (e) {
      throw Exception('Failed to remove reaction: $e');
    }
  }

  static Map<String, dynamic>? _firstRow(dynamic response) {
    if (response is Map<String, dynamic>) return response;
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List) {
      for (final item in response) {
        if (item is Map<String, dynamic>) return item;
        if (item is Map) return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }
}
