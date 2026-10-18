import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context_provider.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_launcher_registry.dart';
import 'package:famhub_app/core/workspace/application/workspace_dashboard_provider.dart';
import 'package:famhub_app/features/ai_assistant/infrastructure/ai_gateway_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/advisor_capabilities.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_assistant_launcher.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_state.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_ai_context_provider.dart';
import 'package:famhub_app/features/farm_management/presentation/pages/farmer_advisor_page.dart';

class _FakeGateway implements FarmerAdvisorGateway {
  @override
  Future<AiGatewayResult> ask({
    required String question,
    Map<String, dynamic>? farmContext,
    Map<String, dynamic>? assistantContext,
    Map<String, dynamic>? capabilityEvidence,
    Map<String, dynamic>? conversation,
  }) async {
    return const AiGatewayResult.success(
      elapsed: Duration.zero,
      statusCode: 200,
      requestId: 'req-test',
      output: 'Observe the plant and share a photo.',
    );
  }
}

/// Stands in for the shell app bar's AI Assistant button.
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => AssistantLauncherRegistry.open(context, ref),
          child: const Text('Open assistant'),
        ),
      ),
    );
  }
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required String location,
  String? workspaceType = 'farmer',
}) async {
  final GoRouter router = GoRouter(
    initialLocation: location,
    routes: <RouteBase>[
      GoRoute(path: '/farm', builder: (_, __) => const _Harness()),
      GoRoute(path: '/extension', builder: (_, __) => const _Harness()),
      GoRoute(path: '/marketplace', builder: (_, __) => const _Harness()),
    ],
    errorBuilder: (_, __) => const _Harness(),
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeWorkspaceTypeProvider.overrideWithValue(workspaceType),
        farmAiContextProvider.overrideWithValue(null),
        farmerAdvisorGatewayProvider.overrideWithValue(_FakeGateway()),
        advisorCapabilitiesProvider
            .overrideWithValue(const <AssistantCapability>[]),
        assistantContextProvider(location).overrideWithValue(
          AssistantContext(
            route: location,
            moduleId: 'extension_services',
            moduleName: 'Extension Services',
            workspaceName: 'Kibuye Advisory',
            workspaceType: 'service_provider',
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapOpen(WidgetTester tester) async {
  await tester.tap(find.text('Open assistant'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(AssistantLauncherRegistry.clear);
  tearDown(AssistantLauncherRegistry.clear);

  group('AssistantLauncherRegistry', () {
    test('starts with no registered workspaces', () {
      expect(AssistantLauncherRegistry.registeredWorkspaceTypes, isEmpty);
      expect(AssistantLauncherRegistry.resolve('farmer'), isNull);
      expect(AssistantLauncherRegistry.isRegistered('farmer'), isFalse);
    });

    test('resolves a registered workspace and nothing else', () {
      AssistantLauncherRegistry.register(
        'farmer',
        (context, ref, route) {},
      );

      expect(AssistantLauncherRegistry.isRegistered('farmer'), isTrue);
      expect(AssistantLauncherRegistry.resolve('farmer'), isNotNull);
      expect(AssistantLauncherRegistry.resolve('trader'), isNull);
      expect(AssistantLauncherRegistry.resolve(null), isNull);
      expect(AssistantLauncherRegistry.resolve(''), isNull);
      expect(
        AssistantLauncherRegistry.registeredWorkspaceTypes,
        <String>['farmer'],
      );
    });

    test('re-registering the same workspace is safe', () {
      AssistantLauncherRegistry.register('farmer', (context, ref, route) {});
      AssistantLauncherRegistry.register('farmer', (context, ref, route) {});

      expect(
        AssistantLauncherRegistry.registeredWorkspaceTypes,
        <String>['farmer'],
      );
    });

    test('registerFarmAssistantLauncher covers both advisory workspaces', () {
      registerFarmAssistantLauncher();

      expect(
        AssistantLauncherRegistry.registeredWorkspaceTypes,
        unorderedEquals(<String>['farmer', 'service_provider']),
      );
      expect(kAgriculturalAssistantWorkspaceTypes, contains('farmer'));
      expect(kAgriculturalAssistantWorkspaceTypes,
          contains('service_provider'));
      // Nothing is registered for workspaces that have no assistant yet.
      expect(AssistantLauncherRegistry.isRegistered('trader'), isFalse);
      expect(AssistantLauncherRegistry.isRegistered('institution'), isFalse);
    });
  });

  group('AssistantLauncherRegistry.open', () {
    testWidgets('hands the current route to the registered launcher',
        (tester) async {
      String? capturedRoute;
      String? capturedType;
      AssistantLauncherRegistry.register('farmer', (context, ref, route) {
        capturedRoute = route;
        capturedType = ref.read(activeWorkspaceTypeProvider);
      });

      await _pumpHarness(tester, location: '/marketplace');
      await _tapOpen(tester);

      expect(capturedRoute, '/marketplace');
      expect(capturedType, 'farmer');
      expect(find.byType(FarmerAdvisorPage), findsNothing);
    });

    testWidgets(
        'tells the user plainly when the workspace has no assistant yet',
        (tester) async {
      await _pumpHarness(
        tester,
        location: '/marketplace',
        workspaceType: 'trader',
      );
      await _tapOpen(tester);

      expect(
        find.text(
          'The FAMHUB AI assistant is not available for this workspace yet.',
        ),
        findsOneWidget,
      );
      expect(find.byType(FarmerAdvisorPage), findsNothing);
    });

    testWidgets('opens the advisory assistant from the farm workspace',
        (tester) async {
      registerFarmAssistantLauncher();

      await _pumpHarness(tester, location: '/farm');
      await _tapOpen(tester);

      expect(find.byType(FarmerAdvisorPage), findsOneWidget);
      expect(find.text('FAMHUB AI'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('opens the same assistant from the extension workspace',
        (tester) async {
      registerFarmAssistantLauncher();

      await _pumpHarness(tester, location: '/extension');
      await _tapOpen(tester);

      expect(find.byType(FarmerAdvisorPage), findsOneWidget);
      expect(find.text('FAMHUB AI'), findsOneWidget);
    });

    testWidgets('the assistant can be dismissed back to the shell',
        (tester) async {
      registerFarmAssistantLauncher();

      await _pumpHarness(tester, location: '/farm');
      await _tapOpen(tester);
      expect(find.byType(FarmerAdvisorPage), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(FarmerAdvisorPage), findsNothing);
      expect(find.text('Open assistant'), findsOneWidget);
    });
  });
}
