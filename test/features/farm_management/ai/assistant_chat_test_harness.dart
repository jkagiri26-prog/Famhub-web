/// ============================================================
/// ASSISTANT CHAT TEST HARNESS
///
/// Hand-written fakes (no mocking package) for advisor chat persistence.
/// Mirrors test/features/financing/financing_test_harness.dart.
///
/// The same instances can back two separate ProviderContainers, which is
/// how the restart tests prove a conversation survives a full app restart.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/repositories/assistant_chat_repository.dart';

/// In-memory [AssistantChatRepository] with per-operation failure switches.
class InMemoryAssistantChatRepository implements AssistantChatRepository {
  InMemoryAssistantChatRepository({
    List<AssistantConversation>? seedConversations,
    Map<String, List<AssistantChatMessage>>? seedMessages,
  }) {
    if (seedConversations != null) {
      conversations.addAll(seedConversations);
    }
    seedMessages?.forEach((String id, List<AssistantChatMessage> rows) {
      messages[id] = List<AssistantChatMessage>.from(rows);
    });
  }

  final List<AssistantConversation> conversations = <AssistantConversation>[];
  final Map<String, List<AssistantChatMessage>> messages =
      <String, List<AssistantChatMessage>>{};

  bool failFetchConversations = false;
  bool failFetchMessages = false;
  bool failCreate = false;
  bool failAppend = false;
  bool failRename = false;
  bool failDelete = false;

  /// Every appendMessage write, in order, for assertions.
  final List<({String conversationId, String role, String text})> writes =
      <({String conversationId, String role, String text})>[];

  int _seq = 0;
  String _nextId(String prefix) => '$prefix-${++_seq}';

  @override
  Future<List<AssistantConversation>> fetchConversations() async {
    if (failFetchConversations) throw Exception('offline');
    final List<AssistantConversation> sorted =
        List<AssistantConversation>.from(conversations)
          ..sort((AssistantConversation a, AssistantConversation b) {
            final DateTime left = a.lastMessageAt ?? a.createdAt;
            final DateTime right = b.lastMessageAt ?? b.createdAt;
            return right.compareTo(left);
          });
    return sorted;
  }

  @override
  Future<List<AssistantChatMessage>> fetchMessages(
    String conversationId, {
    int limit = kMaxStoredMessagesPerConversation,
  }) async {
    if (failFetchMessages) throw Exception('offline');
    final List<AssistantChatMessage> rows =
        messages[conversationId] ?? <AssistantChatMessage>[];
    if (rows.length <= limit) return List<AssistantChatMessage>.from(rows);
    return rows.sublist(rows.length - limit);
  }

  @override
  Future<AssistantConversation> createConversation({
    required String title,
    Map<String, dynamic>? contextMetadata,
  }) async {
    if (failCreate) throw Exception('offline');
    final AssistantConversation created = AssistantConversation(
      id: _nextId('conv'),
      title: title,
      contextMetadata: contextMetadata ?? const <String, dynamic>{},
      createdAt: DateTime.now(),
      lastMessageAt: null,
    );
    conversations.insert(0, created);
    messages[created.id] = <AssistantChatMessage>[];
    return created;
  }

  @override
  Future<void> renameConversation({
    required String conversationId,
    required String title,
  }) async {
    if (failRename) throw Exception('offline');
    final int index = conversations.indexWhere(
      (AssistantConversation c) => c.id == conversationId,
    );
    if (index < 0) return; // RLS would match nothing either.
    conversations[index] = conversations[index].copyWith(title: title);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    if (failDelete) throw Exception('offline');
    conversations.removeWhere(
      (AssistantConversation c) => c.id == conversationId,
    );
    messages.remove(conversationId);
  }

  @override
  Future<void> appendMessage({
    required String conversationId,
    required String role,
    required String text,
    String? errorCode,
  }) async {
    if (failAppend) throw Exception('offline');
    final int index = conversations.indexWhere(
      (AssistantConversation c) => c.id == conversationId,
    );
    if (index < 0) {
      // Matches the real schema: a message can only land in a conversation
      // the same owner holds.
      throw Exception('conversation not found');
    }
    final DateTime now = DateTime.now();
    messages
        .putIfAbsent(conversationId, () => <AssistantChatMessage>[])
        .add(
          AssistantChatMessage(
            id: _nextId('msg'),
            conversationId: conversationId,
            role: role,
            text: text,
            errorCode: errorCode,
            createdAt: now,
          ),
        );
    final AssistantConversation conversation = conversations[index];
    conversations[index] = AssistantConversation(
      id: conversation.id,
      title: conversation.title,
      contextMetadata: conversation.contextMetadata,
      createdAt: conversation.createdAt,
      updatedAt: now,
      lastMessageAt: now,
    );
    writes.add((conversationId: conversationId, role: role, text: text));
  }
}

/// In-memory [AssistantChatPreferences].
class InMemoryAssistantChatPreferences implements AssistantChatPreferences {
  InMemoryAssistantChatPreferences({String? lastConversationId})
    : lastId = lastConversationId;

  String? lastId;
  int writeCount = 0;

  @override
  Future<String?> readLastConversationId() async => lastId;

  @override
  Future<void> writeLastConversationId(String? conversationId) async {
    lastId = conversationId;
    writeCount++;
  }
}
