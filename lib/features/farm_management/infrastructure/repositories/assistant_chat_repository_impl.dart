/// ============================================================
/// ASSISTANT CHAT REPOSITORY — Supabase implementation
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   infrastructure/repositories/ = concrete data access
///
/// ✅ Responsibilities:
///   - Read/write assistant.conversations + assistant.messages
///   - Remember the last selected conversation in SharedPreferences
///
/// 🔒 OWNERSHIP RULE:
///   user_id is NEVER sent, read back for filtering, or trusted. The schema
///   defaults it to core.auth_user_id(), a CHECK pins it to the session user,
///   and RLS scopes every row. This client only ever sends content columns.
/// ============================================================
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/farm_management/domain/repositories/assistant_chat_repository.dart';

class SupabaseAssistantChatRepository implements AssistantChatRepository {
  SupabaseAssistantChatRepository(this._client);

  final SupabaseClient _client;

  static const String _schema = 'assistant';

  static const String _conversationColumns =
      'id, title, context, created_at, updated_at, last_message_at';
  static const String _messageColumns =
      'id, conversation_id, role, content, error_code, created_at';

  @override
  Future<List<AssistantConversation>> fetchConversations() async {
    final List<dynamic> rows = await _client
        .schema(_schema)
        .from('conversations')
        .select(_conversationColumns)
        .order('last_message_at', ascending: false, nullsFirst: false)
        .order('created_at', ascending: false);
    return rows
        .map((dynamic row) => _conversationFromRow(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<List<AssistantChatMessage>> fetchMessages(
    String conversationId, {
    int limit = kMaxStoredMessagesPerConversation,
  }) async {
    final List<dynamic> rows = await _client
        .schema(_schema)
        .from('messages')
        .select(_messageColumns)
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit);
    return rows
        .map((dynamic row) => _messageFromRow(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<AssistantConversation> createConversation({
    required String title,
    Map<String, dynamic>? contextMetadata,
  }) async {
    // Deliberately only content columns: ownership comes from the schema
    // default (core.auth_user_id()), never from this payload.
    final Map<String, dynamic> row = await _client
        .schema(_schema)
        .from('conversations')
        .insert(<String, dynamic>{
          'title': title,
          if (contextMetadata != null && contextMetadata.isNotEmpty)
            'context': contextMetadata,
        })
        .select(_conversationColumns)
        .single();
    return _conversationFromRow(row);
  }

  @override
  Future<void> renameConversation({
    required String conversationId,
    required String title,
  }) async {
    // RLS: rows the caller does not own simply do not match.
    await _client
        .schema(_schema)
        .from('conversations')
        .update(<String, dynamic>{'title': title})
        .eq('id', conversationId);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    // Messages go with it via ON DELETE CASCADE.
    await _client
        .schema(_schema)
        .from('conversations')
        .delete()
        .eq('id', conversationId);
  }

  @override
  Future<void> appendMessage({
    required String conversationId,
    required String role,
    required String text,
    String? errorCode,
  }) async {
    await _client.schema(_schema).from('messages').insert(<String, dynamic>{
      'conversation_id': conversationId,
      'role': role,
      'content': text,
      if (errorCode != null) 'error_code': errorCode,
    });
  }

  AssistantConversation _conversationFromRow(Map<String, dynamic> row) {
    final dynamic metadata = row['context'];
    return AssistantConversation(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? 'New conversation',
      contextMetadata: metadata is Map<String, dynamic>
          ? metadata
          : const <String, dynamic>{},
      createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(row['updated_at']),
      lastMessageAt: _parseDate(row['last_message_at']),
    );
  }

  AssistantChatMessage _messageFromRow(Map<String, dynamic> row) {
    return AssistantChatMessage(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      role: row['role'] as String,
      text: (row['content'] as String?) ?? '',
      errorCode: row['error_code'] as String?,
      createdAt: _parseDate(row['created_at']) ?? DateTime.now(),
    );
  }

  DateTime? _parseDate(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// SharedPreferences-backed memory of the last selected conversation.
class SharedPreferencesAssistantChatPreferences
    implements AssistantChatPreferences {
  SharedPreferencesAssistantChatPreferences();

  static const String _key = 'farmer_advisor_last_conversation_id';

  @override
  Future<String?> readLastConversationId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> writeLastConversationId(String? conversationId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (conversationId == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, conversationId);
    }
  }
}
