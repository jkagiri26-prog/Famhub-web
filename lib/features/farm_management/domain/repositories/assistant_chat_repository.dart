/// ============================================================
/// ASSISTANT CHAT REPOSITORY — domain contract
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   domain/repositories/ = backend-ready contracts, NOT Supabase-coupled
///
/// ✅ Responsibilities:
///   - Persist advisor conversations and messages for the signed-in user
///   - Restore them after closing/reopening the assistant or restarting
///
/// ❌ Does NOT:
///   - Carry or trust any owner id — ownership is derived server-side from
///     the authenticated session (schema default + CHECK + RLS). The client
///     never sends, reads or filters by user_id.
///   - Lock a conversation to a module or entity — module/route/workspace
///     labels ride as free metadata only.
/// ============================================================
library;

/// How many messages load per conversation when it is opened. The gateway
/// already receives a much smaller window (kMaxConversationTurns), so old
/// replies are never blindly re-fed to the model.
const int kMaxStoredMessagesPerConversation = 100;

/// One saved advisor conversation owned by the signed-in user.
class AssistantConversation {
  const AssistantConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.contextMetadata = const <String, dynamic>{},
  });

  final String id;
  final String title;

  /// Module/route/workspace LABELS captured when the thread was created.
  /// Descriptive metadata only — never a binding and never an id.
  final Map<String, dynamic> contextMetadata;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;

  AssistantConversation copyWith({String? title}) {
    return AssistantConversation(
      id: id,
      title: title ?? this.title,
      contextMetadata: contextMetadata,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessageAt: lastMessageAt,
    );
  }
}

/// One persisted message. `role` is `farmer` or `adviser`.
class AssistantChatMessage {
  const AssistantChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.text,
    required this.createdAt,
    this.errorCode,
  });

  final String id;
  final String conversationId;
  final String role;
  final String text;
  final String? errorCode;
  final DateTime createdAt;
}

/// Persistence seam for the advisor's chat history.
///
/// Every method operates on the signed-in user's own rows only — enforced by
/// the database (RLS + schema CHECK), not by anything this client sends.
abstract interface class AssistantChatRepository {
  /// Conversations for the current user, most recently active first.
  Future<List<AssistantConversation>> fetchConversations();

  /// The last [limit] messages of [conversationId], oldest first.
  Future<List<AssistantChatMessage>> fetchMessages(
    String conversationId, {
    int limit = kMaxStoredMessagesPerConversation,
  });

  /// Creates an empty conversation for the current user.
  Future<AssistantConversation> createConversation({
    required String title,
    Map<String, dynamic>? contextMetadata,
  });

  Future<void> renameConversation({
    required String conversationId,
    required String title,
  });

  /// Removes the conversation and (via cascade) its messages.
  Future<void> deleteConversation(String conversationId);

  /// Appends one message. Never sends an owner id.
  Future<void> appendMessage({
    required String conversationId,
    required String role,
    required String text,
    String? errorCode,
  });
}

/// Remembers which conversation was selected across app restarts.
/// Local-only preference; failure to write it never loses messages.
abstract interface class AssistantChatPreferences {
  Future<String?> readLastConversationId();

  Future<void> writeLastConversationId(String? conversationId);
}
