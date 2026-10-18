import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context_provider.dart';
import 'package:famhub_app/features/ai_assistant/infrastructure/ai_gateway_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/advisor_capabilities.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_state.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_ai_context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_ai_context_service.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/farmer_advisor_page.dart';

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
}) async {
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        farmerAdvisorGatewayProvider.overrideWithValue(gateway),
        farmAiContextProvider.overrideWithValue(farmContext),
        advisorCapabilitiesProvider
            .overrideWithValue(const <AssistantCapability>[]),
        assistantContextProvider(route).overrideWithValue(assistantContext),
      ],
      child: MaterialApp(
        home: FarmerAdvisorPage(initialRoute: route),
      ),
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
        advisorCapabilitiesProvider
            .overrideWithValue(const <AssistantCapability>[]),
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
      expect(
        find.text('Ask about your crops or livestock.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);

      // The static mock experts are gone for good.
      expect(find.textContaining('Dr. Jane Kamau'), findsNothing);
      expect(find.textContaining('Officer Samuel Owen'), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(find.byType(NetworkImage), findsNothing);
    });

    testWidgets('shows a back control so the shell can be regained',
        (tester) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('reports the resolved page, module and workspace as labels',
        (tester) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      expect(find.textContaining('Farm Management'), findsOneWidget);
      expect(find.textContaining('Kibuye Farm'), findsOneWidget);
      // The banner is one string of joined labels.
      expect(
        find.text('Farm Management · Kibuye Farm · Kibuye Farm'),
        findsOneWidget,
      );
    });

    testWidgets('states plainly when nothing but the route is known',
        (tester) async {
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

    testWidgets('states that farm context is included when it exists',
        (tester) async {
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
      expect(
        find.text('Consider testing the soil pH first.'),
        findsOneWidget,
      );
      expect(find.byType(SelectableText), findsWidgets);
      // The reply is never handed to a markup renderer.
      expect(
        find.ancestor(
          of: find.text('Consider testing the soil pH first.'),
          matching: find.byType(SelectableText),
        ),
        findsWidgets,
      );
    });

    testWidgets('shows a thinking indicator while the request is in flight',
        (tester) async {
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

    testWidgets('shows a recoverable failure with a retry action',
        (tester) async {
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

    testWidgets('forwards the shell context envelope with every question',
        (tester) async {
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

    testWidgets('always states the advisory limitation and a human route',
        (tester) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      expect(
        find.textContaining('Advice is generated and may be uncertain'),
        findsOneWidget,
      );
      expect(find.textContaining('county extension officer'), findsOneWidget);
      expect(find.textContaining('does not contact or book anyone'),
          findsOneWidget);
    });

    testWidgets('never claims a diagnosis or a guaranteed outcome',
        (tester) async {
      await _pumpPage(tester, gateway: _FakeGateway());

      expect(find.textContaining('may be uncertain'), findsOneWidget);
      expect(find.textContaining('qualified professional'), findsOneWidget);
    });

    testWidgets('chat history survives closing and reopening the assistant',
        (tester) async {
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
      ProviderScope.containerOf(tester.element(find.byType(_AssistantHost)))
          .read(_farmRefreshSeedProvider.notifier)
          .bump();
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
}
