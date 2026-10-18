/// ============================================================
/// FARMER ADVISOR — APPLICATION STATE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/ai/ = AI application layer
///
/// ✅ PATTERN: NotifierProvider (matches Agri Connect controllers)
///
/// Owns the advisory conversation: sends one question at a time, keeps the
/// visible history, attaches the current shell [AssistantContext], and
/// reports every gateway outcome as recoverable state so no ordinary
/// failure escapes into the UI as an exception.
///
/// Context is passed in per request (not cached in state), so a question
/// sent after switching workspace or module carries that new context rather
/// than a stale one.
///
/// 💾 PERSISTENCE:
///   Committed turns (question + answer) are written to Supabase through
///   [AssistantChatRepository]. The last selected conversation is restored on
///   startup, so history survives closing the assistant or restarting the
///   app. Writes are never allowed to silently disappear: a failed write is
///   kept in a pending queue, surfaced in state, and retryable. Module,
///   route and workspace labels are stored as free metadata only — the
///   conversation is never locked to one module or entity, and user_id is
///   never sent (the database derives the owner from the session).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_subject_resolver.dart';
import 'package:famhub_app/features/ai_assistant/infrastructure/ai_gateway_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/advisor_capabilities.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_service.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_ai_context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/assistant_chat_repository.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_ai_context_service.dart';
import 'package:famhub_app/features/farm_management/infrastructure/repositories/assistant_chat_repository_impl.dart';

/// Production gateway. Overridden with a fake in tests.
final farmerAdvisorGatewayProvider = Provider<FarmerAdvisorGateway>((ref) {
  return FarmerAdvisorService(
    AiGatewayService(SupabaseService.instance.client),
  );
});

/// Production chat persistence. Overridden with an in-memory fake in tests.
///
/// The repository never sends an owner id: ownership is enforced by the
/// database (schema default + CHECK + RLS).
final assistantChatRepositoryProvider = Provider<AssistantChatRepository>((
  ref,
) {
  return SupabaseAssistantChatRepository(SupabaseService.instance.client);
});

/// Which conversation was selected last. Overridden in tests.
final assistantChatPreferencesProvider = Provider<AssistantChatPreferences>((
  ref,
) {
  return SharedPreferencesAssistantChatPreferences();
});

/// Role of one visible message.
enum AdvisorRole { farmer, adviser }

/// How many recent conversation turns ride along with a gateway request,
/// and the per-turn character cap. A long chat is trimmed well below the
/// gateway's 100 kB prompt budget, so old replies are never re-fed whole.
const int kMaxConversationTurns = 6;
const int kMaxConversationTurnChars = 400;

/// One message in the visible conversation.
class AdvisorMessage {
  const AdvisorMessage({
    required this.role,
    required this.text,
    this.errorCode,
  });

  final AdvisorRole role;
  final String text;

  /// Set only on a failure placeholder.
  final String? errorCode;

  bool get isFarmer => role == AdvisorRole.farmer;
}

/// Overall request status. `ready` covers both first load and a settled turn.
enum AdvisorStatus { ready, loading, failure }

/// Load state of the conversation LIST (history drawer).
enum AdvisorHistoryStatus { loading, ready, failure }

/// Immutable view state for the assistant.
class FarmerAdvisorState {
  const FarmerAdvisorState({
    this.status = AdvisorStatus.ready,
    this.messages = const <AdvisorMessage>[],
    this.hasFarmContext = false,
    this.pendingQuestion,
    this.lastErrorCode,
    this.historyStatus = AdvisorHistoryStatus.loading,
    this.conversations = const <AssistantConversation>[],
    this.activeConversationId,
    this.openingConversation = false,
    this.openConversationFailed = false,
    this.unsavedMessageCount = 0,
    this.persistenceFailed = false,
    this.managementError,
  });

  final AdvisorStatus status;
  final List<AdvisorMessage> messages;

  /// True only when the farm context provider actually produced a context.
  final bool hasFarmContext;

  /// The question that is in flight, or that failed and can be retried.
  final String? pendingQuestion;

  final String? lastErrorCode;

  /// Load state of the saved-conversations list.
  final AdvisorHistoryStatus historyStatus;
  final List<AssistantConversation> conversations;
  final String? activeConversationId;

  /// True while a selected conversation's messages are being fetched.
  final bool openingConversation;

  /// True when opening a selected conversation failed (offline, deleted…).
  final bool openConversationFailed;

  /// Messages written to (or waiting on) persistence.
  final int unsavedMessageCount;

  /// True when at least one message could not be saved. Never silent — the
  /// UI must show this and offer a retry.
  final bool persistenceFailed;

  /// `rename_failed` / `delete_failed` for conversation management errors.
  final String? managementError;

  bool get isLoading => status == AdvisorStatus.loading;
  bool get canRetry =>
      status == AdvisorStatus.failure && pendingQuestion != null;
  bool get isEmpty => messages.isEmpty;

  /// A persistence failure that still has messages waiting to be saved.
  bool get persistenceWarning => persistenceFailed && unsavedMessageCount > 0;

  FarmerAdvisorState copyWith({
    AdvisorStatus? status,
    List<AdvisorMessage>? messages,
    bool? hasFarmContext,
    String? pendingQuestion,
    String? lastErrorCode,
    AdvisorHistoryStatus? historyStatus,
    List<AssistantConversation>? conversations,
    String? activeConversationId,
    bool? openingConversation,
    bool? openConversationFailed,
    int? unsavedMessageCount,
    bool? persistenceFailed,
    String? managementError,
    bool clearPending = false,
    bool clearError = false,
    bool clearActiveConversation = false,
    bool clearManagementError = false,
  }) {
    return FarmerAdvisorState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      hasFarmContext: hasFarmContext ?? this.hasFarmContext,
      pendingQuestion: clearPending
          ? null
          : (pendingQuestion ?? this.pendingQuestion),
      lastErrorCode: clearError ? null : (lastErrorCode ?? this.lastErrorCode),
      historyStatus: historyStatus ?? this.historyStatus,
      conversations: conversations ?? this.conversations,
      activeConversationId: clearActiveConversation
          ? null
          : (activeConversationId ?? this.activeConversationId),
      openingConversation: openingConversation ?? this.openingConversation,
      openConversationFailed:
          openConversationFailed ?? this.openConversationFailed,
      unsavedMessageCount: unsavedMessageCount ?? this.unsavedMessageCount,
      persistenceFailed: persistenceFailed ?? this.persistenceFailed,
      managementError: clearManagementError
          ? null
          : (managementError ?? this.managementError),
    );
  }
}

/// One committed turn waiting to reach Supabase. Written turn by turn so a
/// failed write can be retried without duplicating what already landed.
class _PendingTurn {
  _PendingTurn({
    required this.conversationId,
    required this.title,
    required this.contextMetadata,
    required this.farmerText,
    required this.adviserText,
  });

  String? conversationId;
  bool farmerSaved = false;
  bool adviserSaved = false;
  final String title;
  final Map<String, dynamic> contextMetadata;
  final String farmerText;
  final String adviserText;

  int get unsavedCount => (farmerSaved ? 0 : 1) + (adviserSaved ? 0 : 1);
}

/// Drives one advisory conversation.
class FarmerAdvisorController extends Notifier<FarmerAdvisorState> {
  /// Guards against a stale response overwriting a newer turn, which also
  /// covers disposal mid-request.
  int _requestToken = 0;

  /// Invalidates an in-flight history restore/open when the user switches
  /// conversations, starts a new chat, or retries the list load.
  int _sessionEpoch = 0;

  /// Context captured for the question currently in flight, so a retry after
  /// a failure re-sends with the same envelope.
  AssistantContext? _activeContext;

  /// The conversation new turns are written into, mirrored into state.
  String? _activeConversationId;

  /// Committed turns whose writes have not completed yet, in order.
  final List<_PendingTurn> _pendingTurns = <_PendingTurn>[];
  bool _flushing = false;

  @override
  FarmerAdvisorState build() {
    // Deliberately a read, never a watch.
    //
    // Watching farmAiContextProvider here would make the farm lifecycle,
    // hierarchy and farm-context providers dependencies of this controller.
    // Any of them rebuilding (farm data loading, selecting a field, a
    // refresh while the chat is closed) would re-run build(), and a re-run
    // REPLACES the whole FarmerAdvisorState with a fresh one — silently
    // erasing the conversation. That is what made the chat forget
    // everything between closing and reopening it.
    //
    // build() is therefore dependency-free and runs exactly once for the
    // life of the container, so the conversation survives. The farm context
    // is re-read per request in ask(), and the UI reads farmAiContextProvider
    // directly for its live banner.
    final FarmAiContext? farmContext = ref.read(farmAiContextProvider);

    // Restore saved history exactly once per container. Deferred to a
    // microtask so no state write happens while build() is still running,
    // and never watched, for the same reason as above.
    Future<void>.microtask(_restoreHistory);

    return FarmerAdvisorState(hasFarmContext: farmContext != null);
  }

  /// Sends [question] together with [assistantContext].
  ///
  /// Ignored while a request is already in flight, and never calls the
  /// gateway for a blank question.
  Future<void> ask(
    String question, {
    required AssistantContext assistantContext,
  }) async {
    final String trimmed = question.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    final int token = ++_requestToken;
    final FarmAiContext? farmContext = ref.read(farmAiContextProvider);
    _activeContext = assistantContext;

    // Captured before this turn is appended: the conversation the question
    // is being asked *into*, used both to resolve the active subject and
    // to brief the stateless gateway on prior turns.
    final List<String> priorQuestions = state.messages
        .where((m) => m.isFarmer)
        .map((m) => m.text)
        .toList(growable: false);
    final List<AdvisorMessage> priorMessages = state.messages;

    state = state.copyWith(
      status: AdvisorStatus.loading,
      hasFarmContext: farmContext != null,
      pendingQuestion: trimmed,
      clearError: true,
      messages: <AdvisorMessage>[
        ...state.messages,
        AdvisorMessage(role: AdvisorRole.farmer, text: trimmed),
      ],
    );

    // Resolve follow-ups and references BEFORE capability routing: the
    // gates see the question with the active subject made explicit (only
    // when the question itself did not name one), so "Do we have any
    // maize?" after a marketplace turn routes to marketplace listings while
    // an explicit "What's the weather forecast?" still routes itself.
    final AdvisorSubjectResolution subject = resolveAdvisorSubject(
      question: trimmed,
      priorQuestions: priorQuestions,
      moduleId: assistantContext.moduleId,
      route: assistantContext.route,
    );

    // Capability first. The model never chooses or executes a capability:
    // the question is matched locally, the capability resolves its own
    // authorized inputs, and only already-retrieved evidence is handed on.
    Map<String, dynamic>? capabilityEvidence;
    final AssistantCapability? capability = _selectCapability(
      subject.routingQuestion,
    );
    if (capability != null) {
      AssistantCapabilityOutcome outcome;
      try {
        // The capability runs on the farmer's own words — the routing
        // annotation exists only to select it.
        outcome = await capability.run(
          question: trimmed,
          assistantContext: assistantContext,
        );
      } catch (_) {
        // A capability must not throw, but a future one might. Report it
        // honestly rather than letting it escape into the UI.
        outcome = const AssistantCapabilityOutcome.failure(
          capabilityId: 'unknown',
          code: 'capability_failed',
          text: 'I could not complete that request just now. Please try again.',
        );
      }

      if (token != _requestToken) return;

      if (outcome.kind != AssistantCapabilityOutcomeKind.evidence) {
        final String answer = outcome.text ?? '';
        _appendAdviserTurn(answer);
        if (answer.trim().isNotEmpty) {
          _persistTurn(
            farmerText: trimmed,
            adviserText: answer,
            assistantContext: assistantContext,
          );
        }
        return;
      }
      capabilityEvidence = outcome.evidence;
    }

    final AiGatewayResult result;
    try {
      result = await ref
          .read(farmerAdvisorGatewayProvider)
          .ask(
            question: trimmed,
            farmContext: farmContext?.toJson(),
            assistantContext: assistantContext.toJson(),
            capabilityEvidence: capabilityEvidence,
            conversation: _conversation(
              activeSubject: subject.subject,
              priorMessages: priorMessages,
            ),
          );
    } catch (_) {
      // The gateway contract never throws, but a fake or a future refactor
      // might. Treat it as an ordinary recoverable failure.
      if (token != _requestToken) return;
      state = state.copyWith(
        status: AdvisorStatus.failure,
        lastErrorCode: 'unexpected_error',
      );
      return;
    }

    if (token != _requestToken) return;

    if (result.succeeded) {
      final String answer = result.output!;
      state = state.copyWith(
        status: AdvisorStatus.ready,
        clearPending: true,
        clearError: true,
        messages: <AdvisorMessage>[
          ...state.messages,
          AdvisorMessage(role: AdvisorRole.adviser, text: answer),
        ],
      );
      // Only committed turns are persisted. A failed turn stays retryable in
      // memory and is written exactly once, when it completes.
      _persistTurn(
        farmerText: trimmed,
        adviserText: answer,
        assistantContext: assistantContext,
      );
      return;
    }

    state = state.copyWith(
      status: AdvisorStatus.failure,
      lastErrorCode: result.code,
    );
  }

  /// Re-sends the question that last failed, with the context it was
  /// originally asked in.
  Future<void> retry() async {
    final String? question = state.pendingQuestion;
    final AssistantContext? context = _activeContext;
    if (question == null || context == null || state.isLoading) return;

    // Drop the failed turn's farmer line so the retry does not duplicate it.
    final List<AdvisorMessage> trimmed = List<AdvisorMessage>.from(
      state.messages,
    );
    for (int i = trimmed.length - 1; i >= 0; i--) {
      if (trimmed[i].isFarmer && trimmed[i].text == question) {
        trimmed.removeAt(i);
        break;
      }
      if (!trimmed[i].isFarmer) break;
    }
    state = state.copyWith(messages: trimmed, clearPending: true);
    await ask(question, assistantContext: context);
  }

  // ── History: restore, open, new chat ────────────────────────────────

  /// Loads the saved conversation list, then restores the conversation that
  /// was selected last (if it still exists) together with its recent
  /// messages. Failures surface as [AdvisorHistoryStatus.failure] — the
  /// list is never silently empty when the load failed.
  Future<void> _restoreHistory() async {
    final int epoch = _sessionEpoch;
    _tryState(
      () => state.copyWith(
        historyStatus: AdvisorHistoryStatus.loading,
        clearManagementError: true,
      ),
    );
    try {
      final AssistantChatRepository repository = ref.read(
        assistantChatRepositoryProvider,
      );
      final List<AssistantConversation> conversations = await repository
          .fetchConversations();
      if (epoch != _sessionEpoch) return;

      String? lastId;
      try {
        lastId = await ref
            .read(assistantChatPreferencesProvider)
            .readLastConversationId();
      } catch (_) {
        lastId = null;
      }
      if (epoch != _sessionEpoch) return;

      _tryState(
        () => state.copyWith(
          conversations: conversations,
          historyStatus: AdvisorHistoryStatus.ready,
        ),
      );

      // Restore the messages only when the user has not already asked or
      // opened something else while the load was in flight.
      if (lastId == null || !conversations.any((c) => c.id == lastId)) return;
      if (_activeConversationId != null ||
          state.messages.isNotEmpty ||
          state.isLoading) {
        return;
      }

      final List<AssistantChatMessage> stored = await repository.fetchMessages(
        lastId,
      );
      if (epoch != _sessionEpoch) return;
      if (_activeConversationId != null) return;

      _activeConversationId = lastId;
      _tryState(
        () => state.copyWith(
          activeConversationId: lastId,
          messages: <AdvisorMessage>[
            for (final AssistantChatMessage message in stored)
              if (message.role == 'farmer' || message.role == 'adviser')
                AdvisorMessage(
                  role: message.role == 'farmer'
                      ? AdvisorRole.farmer
                      : AdvisorRole.adviser,
                  text: message.text,
                ),
          ],
        ),
      );
    } catch (_) {
      if (epoch != _sessionEpoch) return;
      _tryState(
        () => state.copyWith(historyStatus: AdvisorHistoryStatus.failure),
      );
    }
  }

  /// Retry for the history list's failed state.
  Future<void> retryHistoryLoad() async {
    _sessionEpoch++;
    await _restoreHistory();
  }

  /// Opens a saved conversation: replaces the visible messages with its
  /// stored ones and remembers the selection for the next app start.
  Future<void> selectConversation(String conversationId) async {
    if (_activeConversationId == conversationId || state.isLoading) return;

    final int epoch = ++_sessionEpoch;
    _requestToken++;
    _activeContext = null;
    _tryState(
      () => state.copyWith(
        openingConversation: true,
        openConversationFailed: false,
        clearManagementError: true,
        clearPending: true,
        clearError: true,
      ),
    );

    try {
      final List<AssistantChatMessage> stored = await ref
          .read(assistantChatRepositoryProvider)
          .fetchMessages(conversationId);
      if (epoch != _sessionEpoch) return;

      _activeConversationId = conversationId;
      _tryState(
        () => state.copyWith(
          activeConversationId: conversationId,
          openingConversation: false,
          status: AdvisorStatus.ready,
          openConversationFailed: false,
          clearPending: true,
          clearError: true,
          messages: <AdvisorMessage>[
            for (final AssistantChatMessage message in stored)
              if (message.role == 'farmer' || message.role == 'adviser')
                AdvisorMessage(
                  role: message.role == 'farmer'
                      ? AdvisorRole.farmer
                      : AdvisorRole.adviser,
                  text: message.text,
                ),
          ],
        ),
      );
      await _writeLastConversationPref(conversationId);
    } catch (_) {
      if (epoch != _sessionEpoch) return;
      _tryState(
        () => state.copyWith(
          openingConversation: false,
          openConversationFailed: true,
        ),
      );
    }
  }

  /// Detaches from the current conversation and starts a fresh local chat.
  /// The old conversation stays saved. Pending writes keep their own
  /// conversation ids, so nothing in flight is lost or re-parented.
  void startNewChat() {
    _requestToken++;
    _sessionEpoch++;
    _activeContext = null;
    _activeConversationId = null;
    final FarmerAdvisorState previous = state;
    state = FarmerAdvisorState(
      hasFarmContext: previous.hasFarmContext,
      historyStatus: previous.historyStatus,
      conversations: previous.conversations,
      unsavedMessageCount: previous.unsavedMessageCount,
      persistenceFailed: previous.persistenceFailed,
    );
    _writeLastConversationPref(null);
  }

  // ── Conversation management ─────────────────────────────────────────

  Future<void> renameConversation(String conversationId, String title) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final String bounded = trimmed.length <= 80
        ? trimmed
        : trimmed.substring(0, 80);

    _tryState(() => state.copyWith(clearManagementError: true));
    try {
      await ref
          .read(assistantChatRepositoryProvider)
          .renameConversation(conversationId: conversationId, title: bounded);
      _tryState(
        () => state.copyWith(
          conversations: <AssistantConversation>[
            for (final AssistantConversation conversation
                in state.conversations)
              if (conversation.id == conversationId)
                conversation.copyWith(title: bounded)
              else
                conversation,
          ],
        ),
      );
    } catch (_) {
      _tryState(() => state.copyWith(managementError: 'rename_failed'));
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    _tryState(() => state.copyWith(clearManagementError: true));
    try {
      await ref
          .read(assistantChatRepositoryProvider)
          .deleteConversation(conversationId);

      // Its queued writes (if any) belong to a thread the user just
      // destroyed — dropping them is the explicit delete, not a silent loss.
      _pendingTurns.removeWhere((t) => t.conversationId == conversationId);

      final List<AssistantConversation> remaining =
          List<AssistantConversation>.from(state.conversations)
            ..removeWhere((c) => c.id == conversationId);

      if (_activeConversationId == conversationId) {
        _requestToken++;
        _sessionEpoch++;
        _activeContext = null;
        _activeConversationId = null;
        final FarmerAdvisorState previous = state;
        state = FarmerAdvisorState(
          hasFarmContext: previous.hasFarmContext,
          historyStatus: previous.historyStatus,
          conversations: remaining,
          unsavedMessageCount: _totalUnsaved(),
          persistenceFailed: _totalUnsaved() > 0,
        );
        _writeLastConversationPref(null);
      } else {
        final int unsaved = _totalUnsaved();
        _tryState(
          () => state.copyWith(
            conversations: remaining,
            unsavedMessageCount: unsaved,
            persistenceFailed: unsaved > 0 ? state.persistenceFailed : false,
          ),
        );
      }
    } catch (_) {
      _tryState(() => state.copyWith(managementError: 'delete_failed'));
    }
  }

  // ── Persistence ─────────────────────────────────────────────────────

  /// Queues one committed turn and flushes it. Fire-and-forget from the
  /// answer paths: the answer must never wait on, or be lost to, storage.
  Future<void> _persistTurn({
    required String farmerText,
    required String adviserText,
    required AssistantContext assistantContext,
  }) async {
    try {
      _pendingTurns.add(
        _PendingTurn(
          conversationId: _activeConversationId,
          title: _titleFor(farmerText),
          contextMetadata: assistantContext.toJson(),
          farmerText: farmerText,
          adviserText: adviserText,
        ),
      );
      _tryState(
        () =>
            state.copyWith(unsavedMessageCount: state.unsavedMessageCount + 2),
      );
    } catch (_) {
      // Container disposed mid-turn; there is no state to report on.
      return;
    }
    await _flushPendingTurns();
  }

  /// Writes queued turns in order. On failure the queue is kept intact,
  /// state flags it, and [retryPersistence] (or the next turn) retries.
  Future<void> _flushPendingTurns() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final AssistantChatRepository repository = ref.read(
        assistantChatRepositoryProvider,
      );
      while (_pendingTurns.isNotEmpty) {
        final _PendingTurn turn = _pendingTurns.first;
        turn.conversationId ??= _activeConversationId;
        if (turn.conversationId == null) {
          final AssistantConversation created = await repository
              .createConversation(
                title: turn.title,
                contextMetadata: turn.contextMetadata,
              );
          turn.conversationId = created.id;
          await _adoptConversation(created);
        }
        if (!turn.farmerSaved) {
          await repository.appendMessage(
            conversationId: turn.conversationId!,
            role: 'farmer',
            text: turn.farmerText,
          );
          turn.farmerSaved = true;
        }
        if (!turn.adviserSaved) {
          await repository.appendMessage(
            conversationId: turn.conversationId!,
            role: 'adviser',
            text: turn.adviserText,
          );
          turn.adviserSaved = true;
        }
        _pendingTurns.removeAt(0);
        _recountUnsaved();
      }
      _tryState(
        () => state.copyWith(persistenceFailed: false, unsavedMessageCount: 0),
      );
    } catch (_) {
      final int unsaved = _totalUnsaved();
      _tryState(
        () => state.copyWith(
          persistenceFailed: unsaved > 0,
          unsavedMessageCount: unsaved,
        ),
      );
    } finally {
      _flushing = false;
    }
  }

  /// Retries the queue after a persistence failure.
  Future<void> retryPersistence() async {
    if (_pendingTurns.isEmpty) {
      _tryState(
        () => state.copyWith(persistenceFailed: false, unsavedMessageCount: 0),
      );
      return;
    }
    await _flushPendingTurns();
  }

  /// Makes a freshly created conversation the active one and remembers the
  /// selection for the next app start.
  Future<void> _adoptConversation(AssistantConversation created) async {
    _activeConversationId = created.id;
    _tryState(
      () => state.copyWith(
        activeConversationId: created.id,
        conversations: <AssistantConversation>[
          created,
          for (final AssistantConversation conversation in state.conversations)
            if (conversation.id != created.id) conversation,
        ],
      ),
    );
    await _writeLastConversationPref(created.id);
  }

  Future<void> _writeLastConversationPref(String? conversationId) async {
    try {
      await ref
          .read(assistantChatPreferencesProvider)
          .writeLastConversationId(conversationId);
    } catch (_) {
      // A prefs write never loses messages — at worst the next start opens
      // the most recent thread instead of the exact one that was selected.
    }
  }

  void _recountUnsaved() {
    final int unsaved = _totalUnsaved();
    _tryState(
      () => state.copyWith(
        unsavedMessageCount: unsaved,
        persistenceFailed: unsaved == 0 ? false : state.persistenceFailed,
      ),
    );
  }

  int _totalUnsaved() => _pendingTurns.fold(
    0,
    (int sum, _PendingTurn turn) => sum + turn.unsavedCount,
  );

  String _titleFor(String question) {
    final String flat = question.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (flat.isEmpty) return 'New conversation';
    return flat.length <= 60 ? flat : '${flat.substring(0, 59)}…';
  }

  /// Writes state from an async path, tolerating a container that was
  /// disposed while the operation was in flight.
  void _tryState(FarmerAdvisorState Function() next) {
    try {
      state = next();
    } catch (_) {
      // Disposed mid-flight — nothing left to report to.
    }
  }

  /// First approved capability that claims this question, or null so the
  /// ordinary advisory path answers it unchanged.
  AssistantCapability? _selectCapability(String question) {
    final List<AssistantCapability> capabilities = ref.read(
      advisorCapabilitiesProvider,
    );
    for (final AssistantCapability capability in capabilities) {
      if (capability.matches(question)) return capability;
    }
    return null;
  }

  /// Recent conversation for the stateless gateway: the farmer's own
  /// earlier turns and the resolved active subject, so a follow-up or a
  /// subject switch is visible to the model instead of being guessed at.
  ///
  /// Null when there is neither history nor a subject — a first question
  /// with no module context sends exactly the payload it sent before.
  Map<String, dynamic>? _conversation({
    required String? activeSubject,
    required List<AdvisorMessage> priorMessages,
  }) {
    final int start = priorMessages.length > kMaxConversationTurns
        ? priorMessages.length - kMaxConversationTurns
        : 0;
    final List<Map<String, String>> turns = <Map<String, String>>[
      for (final AdvisorMessage message in priorMessages.sublist(start))
        <String, String>{
          'role': message.isFarmer ? 'farmer' : 'adviser',
          'text': message.text.length > kMaxConversationTurnChars
              ? '${message.text.substring(0, kMaxConversationTurnChars)}…'
              : message.text,
        },
    ];
    if (activeSubject == null && turns.isEmpty) return null;
    return <String, dynamic>{
      if (activeSubject != null) 'active_subject': activeSubject,
      if (turns.isNotEmpty) 'turns': turns,
    };
  }

  /// Surfaces a clarification or an honest failure as an ordinary adviser
  /// turn. The gateway is never called, so nothing can be invented.
  void _appendAdviserTurn(String text) {
    state = state.copyWith(
      status: AdvisorStatus.ready,
      clearPending: true,
      clearError: true,
      messages: <AdvisorMessage>[
        ...state.messages,
        AdvisorMessage(role: AdvisorRole.adviser, text: text),
      ],
    );
  }

  /// Clears the visible conversation but keeps this conversation selected.
  /// Use [startNewChat] to detach and begin a new thread.
  void reset() {
    _requestToken++;
    _activeContext = null;
    state = FarmerAdvisorState(
      hasFarmContext: state.hasFarmContext,
      historyStatus: state.historyStatus,
      conversations: state.conversations,
      activeConversationId: state.activeConversationId,
      unsavedMessageCount: state.unsavedMessageCount,
      persistenceFailed: state.persistenceFailed,
    );
  }
}

final farmerAdvisorControllerProvider =
    NotifierProvider<FarmerAdvisorController, FarmerAdvisorState>(
      FarmerAdvisorController.new,
    );
