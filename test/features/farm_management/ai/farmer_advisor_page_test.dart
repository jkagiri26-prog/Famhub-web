import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context_provider.dart';
import 'package:famhub_app/features/ai_assistant/infrastructure/ai_gateway_service.dart';
import 'package:famhub_app/features/auth/presentation/pages/sign_in_screen_page.dart';
import 'package:famhub_app/features/farm_management/application/ai/advisor_capabilities.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_state.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_ai_context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/assistant_chat_repository.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_ai_context_service.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/farmer_advisor_page.dart';

import 'assistant_chat_test_harness.dart';

const AssistantContext _context = AssistantContext(
  route: '/farm',
  moduleId: 'farm_management',
  moduleName: 'Farm Management',
  workspaceName: 'Kibuye Farm',
  workspaceType: 'farmer',
  contextMode: 'farmer',
  entityName: 'Kibuye Farm',
);

class _FakeGateway implements FarmerAdvisorGateway {
  _FakeGateway();

  final String output = 'Consider testing the soil pH first.';
  AiGatewayResult? scripted;
  bool throwOnCall = false;
  Completer<AiGatewayResult>? gate;
  int callCount = 0;
  Map<String, dynamic>? lastAssistantContext;
  Map<String, dynamic>? lastCapabilityEvidence;

  @override
  Future<AiGatewayResult> ask({
    required String question,
    Map<String, dynamic>? farmContext,
    Map<String, dynamic>? assistantContext,
    Map<String, dynamic>? capabilityEvidence,
    Map<String, dynamic>? conversation,
  }) async {
    callCount++;
    lastAssistantContext = assistantContext;
    lastCapabilityEvidence = capabilityEvidence;
    if (throwOnCall) throw Exception('boom');
    final Completer<AiGatewayResult>? pending = gate;
    if (pending != null) {
      gate = null;
      return pending.future;
    }
    if (scripted != null) return scripted!;
    return AiGatewayResult.success(
      elapsed: Duration.zero,
      statusCode: 200,
      requestId: 'req-test',
      output: output,
    );
  }
}

// Deliberately not `const`: each refresh must yield a new instance, the way
// the real provider does, so dependents are notified.
// The `FarmAiContext` must stay non-const: a canonicalized instance would
// never notify dependents, which is exactly the bug this guards against.
// ignore: prefer_const_constructors
FarmAiContext _farmContext() => FarmAiContext(
  stage: 'growing',
  stagePriority: 2,
  hierarchyPath: 'Kibuye Farm → Maize',
  crops: <CropSummary>[
    const CropSummary(name: 'Maize', variety: 'H614', status: 'healthy'),
  ],
  livestock: const <LivestockSummary>[],
  recentActivityCount: 3,
  recommendations: <String>[],
  healthScore: 78,
  isActive: true,
  farmSize: 2.5,
  requiresAction: false,
);

/// Stands in for the farm lifecycle / hierarchy / farm-context providers
/// that FarmAiContext derives from. Bumping it rebuilds FarmAiContext the
/// way a real farm-data refresh does, even while the chat is closed.
class _FarmRefreshSeed extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final _farmRefreshSeedProvider = NotifierProvider<_FarmRefreshSeed, int>(
  _FarmRefreshSeed.new,
);

/// Opens and closes the assistant the way the shell launcher does, so a test
/// can pop the chat and push it again.
class _AssistantHost extends ConsumerWidget {
  const _AssistantHost({required this.route});

  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => FarmerAdvisorPage(initialRoute: route),
            ),
          ),
          child: const Text('open assistant'),
        ),
      ),
    );
  }
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeGateway gateway,
  FarmAiContext? farmContext,
  AssistantContext assistantContext = _context,
  String route = '/farm',
  InMemoryAssistantChatRepository? chat,
  InMemoryAssistantChatPreferences? prefs,
  bool authenticated = true,
}) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        farmerAdvisorGatewayProvider.overrideWithValue(gateway),
        farmAiContextProvider.overrideWithValue(farmContext),
        advisorCapabilitiesProvider.overrideWithValue(
          const <AssistantCapability>[],
        ),
        assistantContextProvider(route).overrideWithValue(assistantContext),
        assistantChatRepositoryProvider.overrideWithValue(
          chat ?? InMemoryAssistantChatRepository(),
        ),
        assistantChatPreferencesProvider.overrideWithValue(
          prefs ?? InMemoryAssistantChatPreferences(),
        ),
        isAuthenticatedProvider.overrideWithValue(authenticated),
      ],
      child: MaterialApp(home: FarmerAdvisorPage(initialRoute: route)),
    ),
  );
  await tester.pump();
}

Future<void> _send(WidgetTester tester, String question) async {
  await tester.enterText(find.byType(TextField), question);
  await tester.pump();
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required _FakeGateway gateway,
  String route = '/farm',
  InMemoryAssistantChatRepository? chat,
  InMemoryAssistantChatPreferences? prefs,
  bool authenticated = true,
}) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        farmerAdvisorGatewayProvider.overrideWithValue(gateway),
        farmAiContextProvider.overrideWith((ref) {
          ref.watch(_farmRefreshSeedProvider);
          return _farmContext();
        }),
        assistantContextProvider(route).overrideWithValue(_context),
        advisorCapabilitiesProvider.overrideWithValue(
          const <AssistantCapability>[],
        ),
        assistantChatRepositoryProvider.overrideWithValue(
          chat ?? InMemoryAssistantChatRepository(),
        ),
        assistantChatPreferencesProvider.overrideWithValue(
          prefs ?? InMemoryAssistantChatPreferences(),
        ),
        isAuthenticatedProvider.overrideWithValue(authenticated),
      ],
      child: MaterialApp(home: _AssistantHost(route: route)),
    ),
  );
  await tester.pump();
}

void main() {
  group('FarmerAdvisorPage', () {
    testWidgets('shows an empty state with no fake experts', (tester) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      expect(find.text('FAMHUB AI'), findsOneWidget);
      expect(find.text('Ask about your crops or livestock.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // The static mock experts are gone for good.
      expect(find.textContaining('Dr. Jane Kamau'), findsNothing);
      expect(find.textContaining('Officer Samuel Owen'), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(NetworkImage), findsNothing);
    });

    testWidgets('shows a back control so the shell can be regained', (
      tester,
    ) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('reports the resolved page, module and workspace as labels', (
      tester,
    ) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      expect(find.textContaining('Farm Management'), findsOneWidget);
      expect(find.textContaining('Kibuye Farm'), findsOneWidget);
      // The banner is one string of joined labels.
      expect(
        find.text('Farm Management · Kibuye Farm · Kibuye Farm'),
        findsOneWidget,
      );
    });

    testWidgets('states plainly when nothing but the route is known', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        gateway: _FakeGateway(),
        assistantContext: const AssistantContext(route: '/unknown-page'),
      );

      expect(find.text('No page context'), findsOneWidget);
      expect(find.textContaining('Farm Management'), findsNothing);
      expect(find.textContaining('Kibuye Farm'), findsNothing);
    });

    testWidgets('states that no farm context is available', (tester) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      expect(
        find.byTooltip('Your farm context is included with each question.'),
        findsNothing,
      );
    });

    testWidgets('states that farm context is included when it exists', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        gateway: _FakeGateway(),
        farmContext: _farmContext(),
      );

      expect(
        find.byTooltip('Your farm context is included with each question.'),
        findsOneWidget,
      );
    });

    testWidgets('renders the reply as plain selectable text', (tester) async {
      await _pumpPage(tester, gateway: _FakeGateway());
      await _send(tester, 'My maize leaves are yellow.');
      await tester.pumpAndSettle();

      expect(find.text('My maize leaves are yellow.'), findsOneWidget);
      expect(find.text('Consider testing the soil pH first.'), findsOneWidget);
      // Flutter draws text onto a canvas on the web, so nothing is
      // copyable unless the app opts in. Both turns sit inside a
      // SelectionArea that does exactly that.
      expect(
        find.ancestor(
          of: find.text('My maize leaves are yellow.'),
          matching: find.byType(SelectionArea),
        ),
        findsWidgets,
      );
      // The reply is never handed to a markup renderer.
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('shows a thinking indicator while the request is in flight', (
      tester,
    ) async {
      final _FakeGateway gateway = _FakeGateway();
      gateway.gate = Completer<AiGatewayResult>();
      await _pumpPage(tester, gateway: gateway);

      await tester.enterText(find.byType(TextField), 'My goat is lame.');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      expect(find.text('Thinking…'), findsOneWidget);
      final IconButton sendButton = tester.widget<IconButton>(
        find.descendant(
          of: find.bySemanticsLabel('Send question'),
          matching: find.byType(IconButton),
        ),
      );
      expect(sendButton.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows a recoverable failure with a retry action', (
      tester,
    ) async {
      final _FakeGateway gateway = _FakeGateway()
        ..scripted = const AiGatewayResult.failure(
          elapsed: Duration.zero,
          statusCode: 502,
          requestId: 'req-test',
          code: 'provider_unavailable',
          message: 'upstream unavailable',
        );
      await _pumpPage(tester, gateway: gateway);

      await _send(tester, 'Is my soil acidic?');
      await tester.pumpAndSettle();

      expect(find.textContaining('provider_unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Is my soil acidic?'), findsOneWidget);
    });

    testWidgets('retry recovers and prints the adviser answer', (tester) async {
      final _FakeGateway gateway = _FakeGateway()
        ..scripted = const AiGatewayResult.failure(
          elapsed: Duration.zero,
          statusCode: 502,
          requestId: 'req-test',
          code: 'provider_unavailable',
          message: 'no',
        );
      await _pumpPage(tester, gateway: gateway);

      await _send(tester, 'Is my soil acidic?');
      await tester.pumpAndSettle();
      expect(gateway.callCount, 1);

      gateway.scripted = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(gateway.callCount, 2);
      expect(find.text('Consider testing the soil pH first.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      // The failed turn's question is not duplicated by the retry.
      expect(find.text('Is my soil acidic?'), findsOneWidget);
    });

    testWidgets('a blank question does not reach the gateway', (tester) async {
      final _FakeGateway gateway = _FakeGateway();
      await _pumpPage(tester, gateway: gateway);

      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(gateway.callCount, 0);
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('forwards the shell context envelope with every question', (
      tester,
    ) async {
      final _FakeGateway gateway = _FakeGateway();
      await _pumpPage(tester, gateway: gateway);
      await _send(tester, 'What now?');
      await tester.pumpAndSettle();

      expect(gateway.callCount, 1);
      // The model only ever receives labels — the route is present, the
      // module id is not.
      expect(gateway.lastAssistantContext, <String, dynamic>{
        'current_page': '/farm',
        'current_module': 'Farm Management',
        'active_workspace': 'Kibuye Farm',
        'context_mode': 'farmer',
        'active_entity': 'Kibuye Farm',
      });
      expect(
        gateway.lastAssistantContext!.values.any((v) => v == 'farm_management'),
        isFalse,
      );
    });

    testWidgets('always states the advisory limitation and a human route', (
      tester,
    ) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      expect(
        find.textContaining('Advice is generated and may be uncertain'),
        findsOneWidget,
      );
      expect(find.textContaining('county extension officer'), findsOneWidget);
      expect(
        find.textContaining('does not contact or book anyone'),
        findsOneWidget,
      );
      // The disclaimer is readable text, so it has to be copyable too.
      expect(
        find.ancestor(
          of: find.textContaining('Advice is generated and may be uncertain'),
          matching: find.byType(SelectionArea),
        ),
        findsWidgets,
      );
    });

    testWidgets('keeps the composer outside the selectable area', (
      tester,
    ) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      // The input field owns its own selection and must not sit inside the
      // page's SelectionArea.
      expect(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(SelectionArea),
        ),
        findsNothing,
      );
    });

    testWidgets('never claims a diagnosis or a guaranteed outcome', (
      tester,
    ) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      expect(find.textContaining('may be uncertain'), findsOneWidget);
      expect(find.textContaining('qualified professional'), findsOneWidget);
    });

    testWidgets('chat history survives closing and reopening the assistant', (
      tester,
    ) async {
      final _FakeGateway gateway = _FakeGateway();
      await _pumpHost(tester, gateway: gateway);

      await tester.tap(find.text('open assistant'));
      await tester.pumpAndSettle();
      await _send(tester, 'My maize leaves are yellow.');
      await tester.pumpAndSettle();

      expect(find.text('My maize leaves are yellow.'), findsOneWidget);
      expect(find.text('Consider testing the soil pH first.'), findsOneWidget);

      // Close the chat.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(FarmerAdvisorPage), findsNothing);
      expect(find.byType(TextField), findsNothing);

      // Farm data refreshes while the chat is closed.
      ProviderScope.containerOf(
        tester.element(find.byType(_AssistantHost)),
      ).read(_farmRefreshSeedProvider.notifier).bump();
      await tester.pumpAndSettle();

      // Reopen it — the conversation is restored, not restarted.
      await tester.tap(find.text('open assistant'));
      await tester.pumpAndSettle();

      expect(find.byType(FarmerAdvisorPage), findsOneWidget);
      expect(find.text('My maize leaves are yellow.'), findsOneWidget);
      expect(find.text('Consider testing the soil pH first.'), findsOneWidget);
      // Nothing was re-sent to the gateway to rebuild the history.
      expect(gateway.callCount, 1);
    });
  });

  group('FarmerAdvisorPage history', () {
    Finder inSheet(Finder matching) =>
        find.descendant(of: find.byType(BottomSheet), matching: matching);

    testWidgets('history sheet lists saved conversations', (tester) async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository(
            seedConversations: <AssistantConversation>[
              AssistantConversation(
                id: 'conv-seeded',
                title: 'Soil advice',
                createdAt: DateTime(2026, 10, 17),
                lastMessageAt: DateTime(2026, 10, 18),
              ),
            ],
          );
      await _pumpPage(tester, gateway: _FakeGateway(), chat: chat);

      await tester.tap(find.byTooltip('Chat history'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Past conversations'), findsOneWidget);
      expect(inSheet(find.text('Soil advice')), findsOneWidget);
      expect(inSheet(find.text('New chat')), findsOneWidget);
    });

    testWidgets('history sheet shows its empty state', (tester) async {
      await _pumpPage(
        tester,
        gateway: _FakeGateway(),
        chat: InMemoryAssistantChatRepository(),
      );

      await tester.tap(find.byTooltip('Chat history'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(inSheet(find.text('No past conversations yet.')), findsOneWidget);
      expect(
        inSheet(find.text('Ask a question to start one.')),
        findsOneWidget,
      );
    });

    testWidgets('history sheet reports a failed list load and can retry', (
      tester,
    ) async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository()..failFetchConversations = true;
      await _pumpPage(tester, gateway: _FakeGateway(), chat: chat);

      await tester.tap(find.byTooltip('Chat history'));
      await tester.pumpAndSettle();

      // The failure is never dressed up as "nothing saved yet".
      expect(
        inSheet(
          find.text("Couldn't load your conversations. Check your connection."),
        ),
        findsOneWidget,
      );
      expect(inSheet(find.text('No past conversations yet.')), findsNothing);

      chat.failFetchConversations = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(
        inSheet(
          find.text("Couldn't load your conversations. Check your connection."),
        ),
        findsNothing,
      );
      expect(inSheet(find.text('No past conversations yet.')), findsOneWidget);
    });

    testWidgets('sending a message saves it and shows it in history', (
      tester,
    ) async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository();
      await _pumpPage(tester, gateway: _FakeGateway(), chat: chat);

      await _send(tester, 'My maize leaves are yellow.');
      await tester.pumpAndSettle();
      expect(chat.writes, hasLength(2));

      await tester.tap(find.byTooltip('Chat history'));
      await tester.pumpAndSettle();

      expect(inSheet(find.text('My maize leaves are yellow.')), findsOneWidget);
      expect(chat.conversations, hasLength(1));
      expect(chat.conversations.single.title, 'My maize leaves are yellow.');
      expect(
        chat.conversations.single.contextMetadata['current_page'],
        '/farm',
      );
    });

    testWidgets('tapping a saved conversation restores it into the chat', (
      tester,
    ) async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository(
            seedConversations: <AssistantConversation>[
              AssistantConversation(
                id: 'conv-seeded',
                title: 'Soil advice',
                createdAt: DateTime(2026, 10, 17),
              ),
            ],
            seedMessages: <String, List<AssistantChatMessage>>{
              'conv-seeded': <AssistantChatMessage>[
                AssistantChatMessage(
                  id: 'm-1',
                  conversationId: 'conv-seeded',
                  role: 'farmer',
                  text: 'pH is low?',
                  createdAt: DateTime(2026, 10, 17, 10),
                ),
                AssistantChatMessage(
                  id: 'm-2',
                  conversationId: 'conv-seeded',
                  role: 'adviser',
                  text: 'Add lime gradually and re-test in a season.',
                  createdAt: DateTime(2026, 10, 17, 10, 1),
                ),
              ],
            },
          );
      final InMemoryAssistantChatPreferences prefs =
          InMemoryAssistantChatPreferences();
      final _FakeGateway gateway = _FakeGateway();
      await _pumpPage(tester, gateway: gateway, chat: chat, prefs: prefs);

      await tester.tap(find.byTooltip('Chat history'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Soil advice'));
      await tester.pumpAndSettle();

      // Sheet closed, messages restored into the conversation view.
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('pH is low?'), findsOneWidget);
      expect(
        find.text('Add lime gradually and re-test in a season.'),
        findsOneWidget,
      );
      // The selection is remembered for the next start.
      expect(prefs.lastId, 'conv-seeded');
      // Opening history never re-sends stored turns to the gateway.
      expect(gateway.callCount, 0);
    });

    testWidgets(
      'the app-bar new chat action starts a fresh chat but keeps the thread',
      (tester) async {
        await _pumpPage(
          tester,
          gateway: _FakeGateway(),
          chat: InMemoryAssistantChatRepository(),
        );

        await _send(tester, 'Question one?');
        await tester.pumpAndSettle();
        expect(find.text('Question one?'), findsOneWidget);

        await tester.tap(find.byTooltip('New chat'));
        await tester.pumpAndSettle();

        // Fresh empty state, conversation untouched below in history.
        expect(find.text('Ask about your crops or livestock.'), findsOneWidget);
        expect(find.text('Question one?'), findsNothing);

        await tester.tap(find.byTooltip('Chat history'));
        await tester.pumpAndSettle();
        expect(inSheet(find.text('Question one?')), findsOneWidget);
      },
    );

    testWidgets('a conversation can be renamed from the history sheet', (
      tester,
    ) async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository();
      await _pumpPage(tester, gateway: _FakeGateway(), chat: chat);

      await _send(tester, 'Question one?');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Chat history'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conversation options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(find.text('Rename conversation'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'Herd health plan',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Rename conversation'), findsNothing);
      expect(inSheet(find.text('Herd health plan')), findsOneWidget);
      expect(chat.conversations.single.title, 'Herd health plan');
    });

    testWidgets('a conversation can be deleted from the history sheet', (
      tester,
    ) async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository();
      await _pumpPage(tester, gateway: _FakeGateway(), chat: chat);

      await _send(tester, 'Question one?');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Chat history'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Conversation options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this conversation?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      // The sheet stays open and honestly shows the empty list again.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(inSheet(find.text('No past conversations yet.')), findsOneWidget);
      expect(chat.conversations, isEmpty);
      expect(chat.messages, isEmpty);
      // The chat behind the sheet is a fresh conversation.
      expect(find.text('Ask about your crops or livestock.'), findsOneWidget);
    });

    testWidgets('a persistence failure shows a visible retry, never silent', (
      tester,
    ) async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository()..failAppend = true;
      await _pumpPage(tester, gateway: _FakeGateway(), chat: chat);

      await _send(tester, 'Is my soil acidic?');
      await tester.pumpAndSettle();

      // The answer itself is never withheld because storage failed.
      expect(find.text('Consider testing the soil pH first.'), findsOneWidget);
      expect(
        find.textContaining('not saved to your history yet'),
        findsOneWidget,
      );
      // The gateway banner's plain 'Retry' is not up here, and the
      // persistence banner must never use that ambiguous label either.
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Retry saving'), findsOneWidget);
      expect(chat.writes, isEmpty);

      chat.failAppend = false;
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('not saved to your history yet'),
        findsNothing,
      );
      expect(find.text('Retry saving'), findsNothing);
      expect(chat.writes, hasLength(2));
      expect(chat.writes.first.text, 'Is my soil acidic?');
    });

    testWidgets('a suggestion chip fills the composer without asking', (
      tester,
    ) async {
      final _FakeGateway gateway = _FakeGateway();
      await _pumpPage(
        tester,
        gateway: gateway,
        chat: InMemoryAssistantChatRepository(),
      );

      expect(find.text("What's the weather forecast?"), findsOneWidget);
      await tester.tap(find.text("What's the weather forecast?"));
      await tester.pumpAndSettle();

      final TextField composer = tester.widget<TextField>(
        find.byType(TextField),
      );
      expect(composer.controller!.text, "What's the weather forecast?");
      // Filling the composer never fires a request by itself.
      expect(gateway.callCount, 0);
    });
  });

  group('FarmerAdvisorPage guest access', () {
    testWidgets(
      'a guest can open and read the advisor and is told to sign up or log in',
      (tester) async {
        final _FakeGateway gateway = _FakeGateway();
        await _pumpPage(
          tester,
          gateway: gateway,
          chat: InMemoryAssistantChatRepository(),
          authenticated: false,
        );

        // The page opens and reads normally for a guest.
        expect(find.byType(FarmerAdvisorPage), findsOneWidget);
        expect(find.text('FAMHUB AI'), findsOneWidget);
        expect(find.text('Ask about your crops or livestock.'), findsOneWidget);

        // …and the guest is told up front, not after a failed attempt.
        expect(
          find.text('Sign up or log in to use the AI assistant.'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, 'Sign up or log in'),
          findsOneWidget,
        );
        // Disclaimer stays visible for everyone.
        expect(find.textContaining('may be uncertain'), findsOneWidget);
      },
    );

    testWidgets(
      'a guest send opens the sign-up prompt and never reaches the gateway',
      (tester) async {
        final _FakeGateway gateway = _FakeGateway();
        await _pumpPage(
          tester,
          gateway: gateway,
          chat: InMemoryAssistantChatRepository(),
          authenticated: false,
        );

        await tester.enterText(find.byType(TextField), 'Is my soil acidic?');
        await tester.pump();
        await tester.tap(find.byTooltip('Send'));
        await tester.pumpAndSettle();

        // The attempt is answered with an explanation, not a silent no-op.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Sign up or log in'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('Create an account or sign in'),
          ),
          findsOneWidget,
        );
        // Nothing was asked, nothing was shown as a reply, nothing persisted.
        expect(gateway.callCount, 0);
        expect(
          find.text('Is my soil acidic?'),
          findsOneWidget,
        ); // composer text
        expect(find.byTooltip('Send'), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Not now'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        // The typed question is still in the composer for after sign-up.
        final TextField composer = tester.widget<TextField>(
          find.byType(TextField),
        );
        expect(composer.controller!.text, 'Is my soil acidic?');
      },
    );

    testWidgets('the sign-up notice opens the real sign-in screen', (
      tester,
    ) async {
      final _FakeGateway gateway = _FakeGateway();
      await _pumpPage(
        tester,
        gateway: gateway,
        chat: InMemoryAssistantChatRepository(),
        authenticated: false,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Sign up or log in'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreenPage), findsOneWidget);
      expect(gateway.callCount, 0);

      // Back returns to the advisor page with the notice still up
      // (the session has not changed).
      final SignInScreenPage screen = tester.widget(
        find.byType(SignInScreenPage),
      );
      screen.onBack();
      await tester.pumpAndSettle();
      expect(find.byType(SignInScreenPage), findsNothing);
      expect(find.byType(FarmerAdvisorPage), findsOneWidget);
      expect(
        find.text('Sign up or log in to use the AI assistant.'),
        findsOneWidget,
      );
    });

    testWidgets('the prompt continue button also opens the sign-in screen', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        gateway: _FakeGateway(),
        chat: InMemoryAssistantChatRepository(),
        authenticated: false,
      );

      await tester.enterText(find.byType(TextField), 'Question?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreenPage), findsOneWidget);
    });

    testWidgets('an authenticated member sees no guest notice', (tester) async {
      await _pumpPage(
        tester,
        gateway: _FakeGateway(),
        chat: InMemoryAssistantChatRepository(),
        authenticated: true,
      );

      expect(
        find.text('Sign up or log in to use the AI assistant.'),
        findsNothing,
      );
      expect(find.byType(AlertDialog), findsNothing);

      await _send(tester, 'My maize leaves are yellow.');
      await tester.pumpAndSettle();
      expect(find.text('My maize leaves are yellow.'), findsOneWidget);
    });
  });
}
