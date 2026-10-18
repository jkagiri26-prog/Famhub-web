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
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/features/ai_assistant/infrastructure/ai_gateway_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/advisor_capabilities.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_service.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_ai_context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_ai_context_service.dart';

/// Production gateway. Overridden with a fake in tests.
final farmerAdvisorGatewayProvider = Provider<FarmerAdvisorGateway>((ref) {
  return FarmerAdvisorService(
    AiGatewayService(SupabaseService.instance.client),
  );
});

/// Role of one visible message.
enum AdvisorRole { farmer, adviser }

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

/// Immutable view state for the assistant.
class FarmerAdvisorState {
  const FarmerAdvisorState({
    this.status = AdvisorStatus.ready,
    this.messages = const <AdvisorMessage>[],
    this.hasFarmContext = false,
    this.pendingQuestion,
    this.lastErrorCode,
  });

  final AdvisorStatus status;
  final List<AdvisorMessage> messages;

  /// True only when the farm context provider actually produced a context.
  final bool hasFarmContext;

  /// The question that is in flight, or that failed and can be retried.
  final String? pendingQuestion;

  final String? lastErrorCode;

  bool get isLoading => status == AdvisorStatus.loading;
  bool get canRetry =>
      status == AdvisorStatus.failure && pendingQuestion != null;
  bool get isEmpty => messages.isEmpty;

  FarmerAdvisorState copyWith({
    AdvisorStatus? status,
    List<AdvisorMessage>? messages,
    bool? hasFarmContext,
    String? pendingQuestion,
    String? lastErrorCode,
    bool clearPending = false,
    bool clearError = false,
  }) {
    return FarmerAdvisorState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      hasFarmContext: hasFarmContext ?? this.hasFarmContext,
      pendingQuestion:
          clearPending ? null : (pendingQuestion ?? this.pendingQuestion),
      lastErrorCode: clearError ? null : (lastErrorCode ?? this.lastErrorCode),
    );
  }
}

/// Drives one advisory conversation.
class FarmerAdvisorController extends Notifier<FarmerAdvisorState> {
  /// Guards against a stale response overwriting a newer turn, which also
  /// covers disposal mid-request.
  int _requestToken = 0;

  /// Context captured for the question currently in flight, so a retry after
  /// a failure re-sends with the same envelope.
  AssistantContext? _activeContext;

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

    // Capability first. The model never chooses or executes a capability:
    // the question is matched locally, the capability resolves its own
    // authorized inputs, and only already-retrieved evidence is handed on.
    Map<String, dynamic>? capabilityEvidence;
    final AssistantCapability? capability = _selectCapability(trimmed);
    if (capability != null) {
      AssistantCapabilityOutcome outcome;
      try {
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
          text:
              'I could not complete that request just now. Please try again.',
        );
      }

      if (token != _requestToken) return;

      if (outcome.kind != AssistantCapabilityOutcomeKind.evidence) {
        _appendAdviserTurn(outcome.text ?? '');
        return;
      }
      capabilityEvidence = outcome.evidence;
    }

    final AiGatewayResult result;
    try {
      result = await ref.read(farmerAdvisorGatewayProvider).ask(
            question: trimmed,
            farmContext: farmContext?.toJson(),
            assistantContext: assistantContext.toJson(),
            capabilityEvidence: capabilityEvidence,
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
      state = state.copyWith(
        status: AdvisorStatus.ready,
        clearPending: true,
        clearError: true,
        messages: <AdvisorMessage>[
          ...state.messages,
          AdvisorMessage(role: AdvisorRole.adviser, text: result.output!),
        ],
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

  /// First approved capability that claims this question, or null so the
  /// ordinary advisory path answers it unchanged.
  AssistantCapability? _selectCapability(String question) {
    final List<AssistantCapability> capabilities = ref
        .read(advisorCapabilitiesProvider);
    for (final AssistantCapability capability in capabilities) {
      if (capability.matches(question)) return capability;
    }
    return null;
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

  /// Clears the conversation.
  void reset() {
    _requestToken++;
    _activeContext = null;
    state = FarmerAdvisorState(hasFarmContext: state.hasFarmContext);
  }
}

final farmerAdvisorControllerProvider =
    NotifierProvider<FarmerAdvisorController, FarmerAdvisorState>(
      FarmerAdvisorController.new,
    );
