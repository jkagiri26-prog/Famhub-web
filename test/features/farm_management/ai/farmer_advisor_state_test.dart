import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/features/ai_assistant/infrastructure/ai_gateway_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_state.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_ai_context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_ai_context_service.dart';

/// Records every call and returns a scripted result. Implements the gateway
/// boundary, so no network and no Supabase client are involved.
class _FakeGateway implements FarmerAdvisorGateway {
  _FakeGateway();

  AiGatewayResult? result;
  bool throwOnCall = false;

  /// When set, the next call parks on this completer until it is completed.
  Completer<AiGatewayResult>? gate;

  final List<String> questions = <String>[];
  final List<Map<String, dynamic>?> farmContexts = <Map<String, dynamic>?>[];
  final List<Map<String, dynamic>?> assistantContexts =
      <Map<String, dynamic>?>[];

  int get callCount => questions.length;

  AiGatewayResult _success(String output) => AiGatewayResult.success(
    elapsed: const Duration(milliseconds: 12),
    statusCode: 200,
    requestId: 'req-test',
    output: output,
  );

  AiGatewayResult _failure(String code) => AiGatewayResult.failure(
    elapsed: const Duration(milliseconds: 12),
    statusCode: 502,
    requestId: 'req-test',
    code: code,
    message: 'upstream unavailable',
  );

  @override
  Future<AiGatewayResult> ask({
    required String question,
    Map<String, dynamic>? farmContext,
    Map<String, dynamic>? assistantContext,
  }) async {
    questions.add(question);
    farmContexts.add(farmContext);
    assistantContexts.add(assistantContext);
    if (throwOnCall) throw Exception('transport failure');
    final Completer<AiGatewayResult>? pending = gate;
    if (pending != null) {
      gate = null;
      return pending.future;
    }
    return result ?? _success('Keep observing the leaves and share a photo.');
  }

  /// Convenience: script a failure then a success.
  void scriptFailureThenSuccess() {
    result = _failure('provider_unavailable');
  }
}

const AssistantContext _assistantContext = AssistantContext(
  route: '/farm',
  moduleId: 'farm_management',
  moduleName: 'Farm Management',
  workspaceName: 'Kibuye Farm',
  workspaceType: 'farmer',
  contextMode: 'farmer',
  entityName: 'Kibuye Farm',
);

FarmAiContext _farmContext() => const FarmAiContext(
  stage: 'growing',
  stagePriority: 2,
  hierarchyPath: 'Kibuye Farm → Maize',
  crops: <CropSummary>[
    CropSummary(name: 'Maize', variety: 'H614', status: 'healthy'),
  ],
  livestock: <LivestockSummary>[],
  recentActivityCount: 3,
  recommendations: <String>['Scout for fall armyworm'],
  healthScore: 78,
  isActive: true,
  farmSize: 2.5,
  requiresAction: false,
);

({ProviderContainer container, _FakeGateway gateway, FarmAiContext? context})
_fixture({FarmAiContext? farmContext}) {
  final _FakeGateway gateway = _FakeGateway();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      farmerAdvisorGatewayProvider.overrideWithValue(gateway),
      farmAiContextProvider.overrideWithValue(farmContext),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, gateway: gateway, context: farmContext);
}

Future<void> _drain() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _ask(
  ProviderContainer container,
  String question,
) {
  return container
      .read(farmerAdvisorControllerProvider.notifier)
      .ask(question, assistantContext: _assistantContext);
}

void main() {
  group('FarmerAdvisorController', () {
    test('starts ready, empty, with no pending question', () async {
      final f = _fixture();
      final FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );

      expect(state.status, AdvisorStatus.ready);
      expect(state.isEmpty, isTrue);
      expect(state.pendingQuestion, isNull);
      expect(state.lastErrorCode, isNull);
      expect(state.isLoading, isFalse);
      expect(state.hasFarmContext, isFalse);
    });

    test('whitespace-only input never reaches the gateway', () async {
      final f = _fixture();
      final FarmerAdvisorController controller = f.container.read(
        farmerAdvisorControllerProvider.notifier,
      );

      await controller.ask('    ', assistantContext: _assistantContext);
      await controller.ask('', assistantContext: _assistantContext);
      await _drain();

      expect(f.gateway.callCount, 0);
      expect(f.container.read(farmerAdvisorControllerProvider).isEmpty, isTrue);
    });

    test('successful ask appends farmer and adviser messages', () async {
      final f = _fixture();
      await _ask(f.container, 'Why are my maize leaves yellow?');
      await _drain();

      final FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.status, AdvisorStatus.ready);
      expect(state.messages, hasLength(2));
      expect(state.messages[0].isFarmer, isTrue);
      expect(state.messages[0].text, 'Why are my maize leaves yellow?');
      expect(state.messages[1].isFarmer, isFalse);
      expect(state.messages[1].text, contains('photo'));
      expect(state.pendingQuestion, isNull);
      expect(state.lastErrorCode, isNull);
    });

    test('supplies serialized farm context to the gateway', () async {
      final FarmAiContext farmContext = _farmContext();
      final f = _fixture(farmContext: farmContext);

      expect(
        f.container.read(farmerAdvisorControllerProvider).hasFarmContext,
        isTrue,
      );

      await _ask(f.container, 'What should I do about fall armyworm?');
      await _drain();

      expect(f.gateway.callCount, 1);
      expect(f.gateway.farmContexts.single, farmContext.toJson());
      expect(f.gateway.farmContexts.single!['stage'], 'growing');
      expect(f.gateway.farmContexts.single!['crops'], isNotEmpty);
    });

    test('always forwards the shell context envelope alongside the question',
        () async {
      final f = _fixture();

      await _ask(f.container, 'My goat is lame.');
      await _drain();

      expect(f.gateway.assistantContexts.single, _assistantContext.toJson());
      expect(f.gateway.assistantContexts.single!['current_page'], '/farm');
      expect(f.gateway.assistantContexts.single!['current_module'],
          'Farm Management');
      expect(
        f.gateway.assistantContexts.single!.containsKey('entity_id'),
        isFalse,
      );
    });

    test('passes null farm context when no farm context exists', () async {
      final f = _fixture();

      await _ask(f.container, 'My goat is lame.');
      await _drain();

      expect(f.gateway.farmContexts.single, isNull);
      // The shell envelope is still sent — only the farm slice is absent.
      expect(f.gateway.assistantContexts.single, isNotNull);
      expect(
        f.container.read(farmerAdvisorControllerProvider).hasFarmContext,
        isFalse,
      );
    });

    test('rejects a duplicate send while a request is in flight', () async {
      final f = _fixture();
      final FarmerAdvisorController controller = f.container.read(
        farmerAdvisorControllerProvider.notifier,
      );

      final Completer<AiGatewayResult> gate = Completer<AiGatewayResult>();
      f.gateway.gate = gate;

      final Future<void> first = controller.ask(
        'First question',
        assistantContext: _assistantContext,
      );
      await _drain();
      expect(
        f.container.read(farmerAdvisorControllerProvider).isLoading,
        isTrue,
      );

      await controller.ask(
        'Second question',
        assistantContext: _assistantContext,
      );
      await _drain();

      expect(f.gateway.callCount, 1);
      expect(f.gateway.questions.single, 'First question');
      expect(f.container.read(farmerAdvisorControllerProvider).messages,
          hasLength(1));

      gate.complete(
        const AiGatewayResult.success(
          elapsed: Duration.zero,
          statusCode: 200,
          requestId: 'req-test',
          output: 'Answer one.',
        ),
      );
      await first;
      await _drain();

      final FarmerAdvisorState settled = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(settled.status, AdvisorStatus.ready);
      expect(settled.messages, hasLength(2));
    });

    test('a gateway failure becomes recoverable state, not an exception',
        () async {
      final f = _fixture();
      f.gateway.result = const AiGatewayResult.failure(
        elapsed: Duration.zero,
        statusCode: 502,
        requestId: 'req-test',
        code: 'provider_unavailable',
        message: 'upstream unavailable',
      );
      await _ask(f.container, 'Is my soil acidic?');

      final FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.status, AdvisorStatus.failure);
      expect(state.lastErrorCode, 'provider_unavailable');
      expect(state.canRetry, isTrue);
      expect(state.pendingQuestion, 'Is my soil acidic?');
      // The question stays visible so the farmer does not lose what they typed.
      expect(state.messages, hasLength(1));
      expect(state.messages.single.isFarmer, isTrue);
    });

    test('retry re-sends the failed question without duplicating it',
        () async {
      final f = _fixture();
      f.gateway.scriptFailureThenSuccess();
      final FarmerAdvisorController controller = f.container.read(
        farmerAdvisorControllerProvider.notifier,
      );

      await controller.ask(
        'Is my soil acidic?',
        assistantContext: _assistantContext,
      );
      expect(
          f.container.read(farmerAdvisorControllerProvider).canRetry, isTrue);

      f.gateway.result = const AiGatewayResult.success(
        elapsed: Duration.zero,
        statusCode: 200,
        requestId: 'req-test',
        output: 'Test the top 15 cm with a pH strip.',
      );
      await controller.retry();
      await _drain();

      final FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(f.gateway.callCount, 2);
      expect(f.gateway.questions.last, 'Is my soil acidic?');
      // The retry carries the context the question was originally asked in.
      expect(f.gateway.assistantContexts.last, _assistantContext.toJson());
      expect(state.status, AdvisorStatus.ready);
      expect(state.messages, hasLength(2));
      expect(
        state.messages.where((m) => m.text == 'Is my soil acidic?').length,
        1,
      );
    });

    test('retry is a no-op once the turn has recovered', () async {
      final f = _fixture();
      final FarmerAdvisorController controller = f.container.read(
        farmerAdvisorControllerProvider.notifier,
      );

      await controller.ask(
        'How deep should I plant?',
        assistantContext: _assistantContext,
      );
      await _drain();

      expect(
          f.container.read(farmerAdvisorControllerProvider).canRetry, isFalse);
      await controller.retry();
      await _drain();
      expect(f.gateway.callCount, 1);
    });

    test('an unexpected throw is reported as a recoverable failure', () async {
      final f = _fixture();
      f.gateway.throwOnCall = true;
      await _ask(f.container, 'My poultry are listless.');

      final FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.status, AdvisorStatus.failure);
      expect(state.lastErrorCode, 'unexpected_error');
      expect(state.canRetry, isTrue);
    });

    test('empty farm context flag is true only when a context exists',
        () async {
      final f = _fixture(farmContext: _farmContext());
      expect(
        f.container.read(farmerAdvisorControllerProvider).hasFarmContext,
        isTrue,
      );
    });

    test('reset clears the conversation but keeps the context flag', () async {
      final f = _fixture(farmContext: _farmContext());
      final FarmerAdvisorController controller = f.container.read(
        farmerAdvisorControllerProvider.notifier,
      );

      await controller.ask(
        'Question one?',
        assistantContext: _assistantContext,
      );
      await _drain();
      controller.reset();

      final FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.isEmpty, isTrue);
      expect(state.status, AdvisorStatus.ready);
      expect(state.hasFarmContext, isTrue);
    });

    test('forwards the farmer question verbatim to the gateway', () async {
      // Prompt composition (including the safety framing) is the service
      // layer's job and is asserted in farmer_advisor_service_test.dart.
      // The controller's contract is to pass the question through untouched.
      final f = _fixture();
      await _ask(f.container, '  What pesticide should I spray?  ');
      await _drain();

      expect(f.gateway.questions.single, 'What pesticide should I spray?');
    });
  });
}
