import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/features/ai_assistant/infrastructure/ai_gateway_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/advisor_capabilities.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_activity_history_capability.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_crop_capability.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_livestock_capability.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_service.dart';
import 'package:famhub_app/features/farm_management/application/ai/farmer_advisor_state.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_ai_context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/asset_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_ai_context_service.dart';
import 'package:famhub_app/features/marketplace/application/ai/marketplace_capability.dart';
import 'package:famhub_app/features/marketplace/domain/entities/listing.dart';
import 'package:famhub_app/features/weather/application/assistant/farm_weather_capability.dart';
import 'package:famhub_app/features/weather/application/providers/weather_providers.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/infrastructure/weather_service.dart';

import 'package:famhub_app/features/farm_management/domain/repositories/assistant_chat_repository.dart';

import 'assistant_chat_test_harness.dart';

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
  final List<Map<String, dynamic>?> capabilityEvidences =
      <Map<String, dynamic>?>[];
  final List<Map<String, dynamic>?> conversations = <Map<String, dynamic>?>[];

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
    Map<String, dynamic>? capabilityEvidence,
    Map<String, dynamic>? conversation,
  }) async {
    questions.add(question);
    farmContexts.add(farmContext);
    assistantContexts.add(assistantContext);
    capabilityEvidences.add(capabilityEvidence);
    conversations.add(conversation);
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

// Deliberately not `const`: every rebuild of FarmAiContext must yield a new
// instance, the way the real provider does, so dependents are notified.
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
  recommendations: <String>['Scout for fall armyworm'],
  healthScore: 78,
  isActive: true,
  farmSize: 2.5,
  requiresAction: false,
);

/// Stands in for the farm lifecycle / hierarchy / farm-context providers
/// that FarmAiContext derives from. Bumping it rebuilds FarmAiContext the
/// way a real farm-data refresh does.
class _FarmRefreshSeed extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final _farmRefreshSeedProvider = NotifierProvider<_FarmRefreshSeed, int>(
  _FarmRefreshSeed.new,
);

({
  ProviderContainer container,
  _FakeGateway gateway,
  FarmAiContext? context,
  InMemoryAssistantChatRepository chat,
  InMemoryAssistantChatPreferences prefs,
})
_fixture({
  FarmAiContext? farmContext,
  List<AssistantCapability> capabilities = const <AssistantCapability>[],
  InMemoryAssistantChatRepository? chat,
  InMemoryAssistantChatPreferences? prefs,
}) {
  final _FakeGateway gateway = _FakeGateway();
  final InMemoryAssistantChatRepository chatRepository =
      chat ?? InMemoryAssistantChatRepository();
  final InMemoryAssistantChatPreferences chatPreferences =
      prefs ?? InMemoryAssistantChatPreferences();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      farmerAdvisorGatewayProvider.overrideWithValue(gateway),
      farmAiContextProvider.overrideWithValue(farmContext),
      advisorCapabilitiesProvider.overrideWithValue(capabilities),
      assistantChatRepositoryProvider.overrideWithValue(chatRepository),
      assistantChatPreferencesProvider.overrideWithValue(chatPreferences),
    ],
  );
  addTearDown(container.dispose);
  return (
    container: container,
    gateway: gateway,
    context: farmContext,
    chat: chatRepository,
    prefs: chatPreferences,
  );
}

Future<void> _drain() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _ask(ProviderContainer container, String question) {
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

    test(
      'always forwards the shell context envelope alongside the question',
      () async {
        final f = _fixture();

        await _ask(f.container, 'My goat is lame.');
        await _drain();

        expect(f.gateway.assistantContexts.single, _assistantContext.toJson());
        expect(f.gateway.assistantContexts.single!['current_page'], '/farm');
        expect(
          f.gateway.assistantContexts.single!['current_module'],
          'Farm Management',
        );
        expect(
          f.gateway.assistantContexts.single!.containsKey('entity_id'),
          isFalse,
        );
      },
    );

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
      expect(
        f.container.read(farmerAdvisorControllerProvider).messages,
        hasLength(1),
      );

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

    test(
      'a gateway failure becomes recoverable state, not an exception',
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
      },
    );

    test('retry re-sends the failed question without duplicating it', () async {
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
        f.container.read(farmerAdvisorControllerProvider).canRetry,
        isTrue,
      );

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
        f.container.read(farmerAdvisorControllerProvider).canRetry,
        isFalse,
      );
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

    test(
      'empty farm context flag is true only when a context exists',
      () async {
        final f = _fixture(farmContext: _farmContext());
        expect(
          f.container.read(farmerAdvisorControllerProvider).hasFarmContext,
          isTrue,
        );
      },
    );

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

    test(
      'the conversation is not erased when the farm context refreshes',
      () async {
        // Reproduces the original defect: FarmAiContext derives from the farm
        // lifecycle, hierarchy and farm-context providers, any of which can
        // rebuild while the chat is open, in the background, or between
        // closing and reopening it. A controller that watches it re-runs
        // build(), which replaced the whole state and wiped the history.
        final _FakeGateway gateway = _FakeGateway();
        final ProviderContainer container = ProviderContainer(
          overrides: [
            farmerAdvisorGatewayProvider.overrideWithValue(gateway),
            farmAiContextProvider.overrideWith((ref) {
              ref.watch(_farmRefreshSeedProvider);
              return _farmContext();
            }),
            advisorCapabilitiesProvider.overrideWithValue(
              const <AssistantCapability>[],
            ),
            assistantChatRepositoryProvider.overrideWithValue(
              InMemoryAssistantChatRepository(),
            ),
            assistantChatPreferencesProvider.overrideWithValue(
              InMemoryAssistantChatPreferences(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Mirrors production: the chat page listens to this controller and its
        // context banner listens to FarmAiContext, so neither is detached.
        final ProviderSubscription<FarmerAdvisorState> chat = container.listen(
          farmerAdvisorControllerProvider,
          (_, __) {},
        );
        final ProviderSubscription<FarmAiContext?> farm = container.listen(
          farmAiContextProvider,
          (_, __) {},
        );
        addTearDown(chat.close);
        addTearDown(farm.close);

        await _ask(container, 'Why are my maize leaves yellow?');
        await _drain();
        expect(
          container.read(farmerAdvisorControllerProvider).messages,
          hasLength(2),
        );

        // Farm data reloads / the selection changes.
        container.read(_farmRefreshSeedProvider.notifier).bump();
        await _drain();

        // Reopen: the same long-lived notifier is read again.
        final FarmerAdvisorState reopened = container.read(
          farmerAdvisorControllerProvider,
        );
        expect(reopened.messages, hasLength(2));
        expect(reopened.messages.first.isFarmer, isTrue);
        expect(reopened.messages.first.text, 'Why are my maize leaves yellow?');
        expect(reopened.messages.last.isFarmer, isFalse);
        expect(reopened.status, AdvisorStatus.ready);
        expect(gateway.callCount, 1);
      },
    );

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

  group('capability routing', () {
    test(
      'a weather question runs the capability and sends its evidence',
      () async {
        final Map<String, dynamic> evidence = <String, dynamic>{
          'capability': 'farm_weather',
          'location_label': 'Kibuye Farm',
          'scope': 'current',
        };
        final _StubCapability capability = _StubCapability(
          id: 'farm_weather',
          isMatch: (String q) => q.toLowerCase().contains('weather'),
          outcome: AssistantCapabilityOutcome.evidence(
            capabilityId: 'farm_weather',
            evidence: evidence,
          ),
        );
        final f = _fixture(capabilities: <AssistantCapability>[capability]);

        await _ask(f.container, "What's the weather on my farm?");
        await _drain();

        expect(capability.runCount, 1);
        // The gateway still receives the question, now with the evidence.
        expect(f.gateway.questions.single, "What's the weather on my farm?");
        expect(f.gateway.capabilityEvidences.single, evidence);
        expect(
          f.container.read(farmerAdvisorControllerProvider).status,
          AdvisorStatus.ready,
        );
      },
    );

    test('a non-weather question keeps the existing advisory path', () async {
      final _StubCapability capability = _StubCapability(
        id: 'farm_weather',
        isMatch: (String q) => q.toLowerCase().contains('weather'),
        outcome: const AssistantCapabilityOutcome.evidence(
          capabilityId: 'farm_weather',
          evidence: <String, dynamic>{'capability': 'farm_weather'},
        ),
      );
      final f = _fixture(capabilities: <AssistantCapability>[capability]);

      await _ask(f.container, 'My maize leaves are yellow.');
      await _drain();

      expect(capability.runCount, 0);
      expect(f.gateway.callCount, 1);
      expect(f.gateway.capabilityEvidences.single, isNull);
      expect(
        f.container.read(farmerAdvisorControllerProvider).messages.last.text,
        'Keep observing the leaves and share a photo.',
      );
    });

    test(
      'the real farm/crop capability hands retrieved evidence to the gateway',
      () async {
        final FarmCropInputs inputs = FarmCropInputs(
          farms: const <FarmEntity>[
            FarmEntity(
              id: 'f1',
              farmName: 'Kibuye Farm',
              isActive: true,
              isVerified: true,
            ),
          ],
          loadFields: (String farmId) async => <FieldEntity>[
            FieldEntity(
              id: 'fd1',
              farmId: farmId,
              fieldName: 'Main Field',
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
          loadCrops: (String farmId, String? fieldId) async => <CropEntity>[
            CropEntity(
              id: 'c1',
              farmId: farmId,
              fieldId: 'fd1',
              cropName: 'Maize',
              variety: 'H614',
              plantingDate: DateTime(2026, 3, 1),
              createdAt: DateTime(2026, 3, 1),
            ),
          ],
        );
        final f = _fixture(
          capabilities: <AssistantCapability>[
            FarmCropCapability(readInputs: () => inputs),
          ],
        );

        await _ask(f.container, 'What crops have I registered on my farm?');
        await _drain();

        expect(
          f.gateway.questions.single,
          'What crops have I registered on my farm?',
        );
        final Map<String, dynamic>? evidence =
            f.gateway.capabilityEvidences.single;
        expect(evidence, isNotNull);
        expect(evidence!['capability'], 'farm_crop_context');
        expect(evidence['_note'], isNotNull);
        expect(evidence['farms'], isNotEmpty);
        expect(
          (evidence['crops'] as List).single,
          containsPair('name', 'Maize'),
        );
        expect(
          f.container.read(farmerAdvisorControllerProvider).status,
          AdvisorStatus.ready,
        );
      },
    );

    test(
      'the real activity capability hands retrieved evidence to the gateway',
      () async {
        final FarmActivityInputs inputs = FarmActivityInputs(
          farms: const <FarmEntity>[
            FarmEntity(
              id: 'f1',
              farmName: 'Kibuye Farm',
              isActive: true,
              isVerified: true,
            ),
          ],
          loadActivities: (String farmId) async => <ActivityModel>[
            ActivityModel(
              id: 'a1',
              activityTypeId: 't1',
              performedAt: DateTime(2026, 4, 2, 9),
              assetId: 'as1',
              notes: 'Private note, contact 0711 999 000',
            ),
          ],
          loadActivityTypeNames: () async => <String, String>{'t1': 'Pruning'},
          loadAssets: (String farmId) async => <AssetEntity>[
            AssetEntity(
              id: 'as1',
              farmId: farmId,
              assetType: 'crop',
              fieldId: 'fd1',
              assetName: 'Coffee',
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
          loadFields: (String farmId) async => <FieldEntity>[
            FieldEntity(
              id: 'fd1',
              farmId: farmId,
              fieldName: 'Main Field',
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        );
        final f = _fixture(
          capabilities: <AssistantCapability>[
            FarmActivityCapability(readInputs: () => inputs),
          ],
        );

        await _ask(f.container, 'When did I last prune on my farm?');
        await _drain();

        expect(f.gateway.questions.single, 'When did I last prune on my farm?');
        final Map<String, dynamic>? evidence =
            f.gateway.capabilityEvidences.single;
        expect(evidence, isNotNull);
        expect(evidence!['capability'], 'farm_activity_history');
        expect(evidence['_note'], isNotNull);
        expect(evidence['ordered_by'], contains('performed_at'));
        final Map<String, dynamic> row =
            (evidence['activities'] as List).single as Map<String, dynamic>;
        expect(row['type'], 'Pruning');
        expect(row['asset'], 'Coffee');
        expect(row['field'], 'Main Field');
        expect(jsonEncode(evidence), isNot(contains('0711')));
        expect(jsonEncode(evidence), isNot(contains('a1')));
        expect(
          f.container.read(farmerAdvisorControllerProvider).status,
          AdvisorStatus.ready,
        );
      },
    );

    test(
      'the real livestock capability hands retrieved evidence to the gateway',
      () async {
        final FarmLivestockInputs inputs = FarmLivestockInputs(
          farms: const <FarmEntity>[
            FarmEntity(
              id: 'f1',
              farmName: 'Kibuye Farm',
              isActive: true,
              isVerified: true,
            ),
          ],
          loadLivestock: (String farmId) async => <LivestockEntity>[
            LivestockEntity(
              id: 'as1',
              farmId: farmId,
              variantId: 'v1',
              species: 'Dairy Fresian',
              breed: 'Fresian',
              count: 12,
              notes: 'Private note, contact 0711 999 000',
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
          loadFields: (String farmId) async => const <FieldEntity>[],
          loadTaxonomy: () async => <LivestockTaxonomyEntry>[
            (variantId: 'v1', itemName: 'dairy', categoryName: 'cattle'),
          ],
          loadActivities: (String farmId) async => const <ActivityModel>[],
          loadActivityTypeNames: () async => const <String, String>{},
          loadProduction: (String farmId) async => const <ProductionEntity>[],
          loadCommodities: () async => const <String, String>{},
          loadUnits: () async => const <String, String>{},
        );
        final f = _fixture(
          capabilities: <AssistantCapability>[
            FarmLivestockCapability(readInputs: () => inputs),
          ],
        );

        await _ask(f.container, 'How many cattle do I have recorded?');
        await _drain();

        expect(
          f.gateway.questions.single,
          'How many cattle do I have recorded?',
        );
        final Map<String, dynamic>? evidence =
            f.gateway.capabilityEvidences.single;
        expect(evidence, isNotNull);
        expect(evidence!['capability'], 'farm_livestock_context');
        expect(evidence['_note'], isNotNull);
        expect(evidence['query_species'], 'cattle');
        final Map<String, dynamic> row =
            (evidence['livestock'] as List).single as Map<String, dynamic>;
        expect(row['species'], 'Dairy Fresian');
        expect((evidence['counts']! as Map<String, int>)['head_recorded'], 12);
        expect(jsonEncode(evidence), isNot(contains('0711')));
        expect(jsonEncode(evidence), isNot(contains('as1')));
        expect(jsonEncode(evidence), isNot(contains('v1"')));
        expect(
          f.container.read(farmerAdvisorControllerProvider).status,
          AdvisorStatus.ready,
        );
      },
    );

    test(
      'an ambiguous farm asks instead of picking one or calling the gateway',
      () async {
        final _StubCapability capability = _StubCapability(
          id: 'farm_weather',
          isMatch: (String q) => true,
          outcome: const AssistantCapabilityOutcome.clarification(
            capabilityId: 'farm_weather',
            text: 'Which farm do you mean? Ask me again naming one.',
          ),
        );
        final f = _fixture(capabilities: <AssistantCapability>[capability]);

        await _ask(f.container, "What's the weather on my farm?");
        await _drain();

        expect(capability.runCount, 1);
        expect(f.gateway.callCount, 0);

        final FarmerAdvisorState state = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(state.status, AdvisorStatus.ready);
        expect(state.messages.last.isFarmer, isFalse);
        expect(state.messages.last.text, startsWith('Which farm do you mean'));
      },
    );

    test(
      'a capability failure is reported honestly and never invented',
      () async {
        final _StubCapability capability = _StubCapability(
          id: 'farm_weather',
          isMatch: (String q) => true,
          outcome: const AssistantCapabilityOutcome.failure(
            capabilityId: 'farm_weather',
            code: 'weather_no_location',
            text: '"Kibuye Farm" has no registered location yet.',
          ),
        );
        final f = _fixture(capabilities: <AssistantCapability>[capability]);

        await _ask(f.container, "What's the weather on my farm?");
        await _drain();

        // Nothing reached the model, so nothing could be invented.
        expect(f.gateway.callCount, 0);

        final FarmerAdvisorState state = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(state.status, AdvisorStatus.ready);
        expect(state.messages.last.text, contains('no registered location'));
        expect(state.lastErrorCode, isNull);
      },
    );

    test('a capability that throws is turned into an honest failure', () async {
      final _StubCapability capability = _StubCapability(
        id: 'farm_weather',
        isMatch: (String q) => true,
        outcome: const AssistantCapabilityOutcome.evidence(
          capabilityId: 'farm_weather',
          evidence: <String, dynamic>{'capability': 'farm_weather'},
        ),
        throwOnRun: true,
      );
      final f = _fixture(capabilities: <AssistantCapability>[capability]);

      await _ask(f.container, "What's the weather on my farm?");
      await _drain();

      expect(f.gateway.callCount, 0);
      final FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.status, AdvisorStatus.ready);
      expect(state.messages.last.isFarmer, isFalse);
      expect(state.messages.last.text, contains('could not complete'));
    });

    test(
      'a later gateway failure can still be retried with its evidence',
      () async {
        final _StubCapability capability = _StubCapability(
          id: 'farm_weather',
          isMatch: (String q) => true,
          outcome: const AssistantCapabilityOutcome.evidence(
            capabilityId: 'farm_weather',
            evidence: <String, dynamic>{'capability': 'farm_weather'},
          ),
        );
        final f = _fixture(capabilities: <AssistantCapability>[capability]);
        f.gateway.scriptFailureThenSuccess();

        await _ask(f.container, "What's the weather on my farm?");
        await _drain();

        FarmerAdvisorState state = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(state.status, AdvisorStatus.failure);
        expect(state.canRetry, isTrue);

        f.gateway.result = const AiGatewayResult.success(
          elapsed: Duration(milliseconds: 12),
          statusCode: 200,
          requestId: 'req-test',
          output: 'It is 24 °C and partly cloudy on Kibuye Farm.',
        );
        await f.container
            .read(farmerAdvisorControllerProvider.notifier)
            .retry();
        await _drain();

        state = f.container.read(farmerAdvisorControllerProvider);
        expect(state.status, AdvisorStatus.ready);
        expect(capability.runCount, 2);
        expect(f.gateway.capabilityEvidences, hasLength(2));
        expect(f.gateway.capabilityEvidences.last, <String, dynamic>{
          'capability': 'farm_weather',
        });
      },
    );
  });

  // ══════════════════════════════════════════════════════════
  // PHASE 3F — contextual AI coordination
  //
  // Real production composition (advisorCapabilitiesProvider untouched);
  // only the data seams are faked, so capability ORDER is the order the
  // app actually offers the request.
  // ══════════════════════════════════════════════════════════
  group('contextual coordination', () {
    const AssistantContext onMarketplace = AssistantContext(
      route: '/marketplace',
      moduleId: 'marketplace',
      moduleName: 'Marketplace',
      workspaceType: 'trader',
    );

    Listing listingFor(String id, String title) => Listing(
      id: id,
      title: title,
      pricePerUnit: 120,
      images: const <String>[],
      entityId: 'ent_secret',
      variantId: 'var_secret',
      stockId: 'stk_secret',
      unitName: 'bag',
      createdAt: DateTime(2026, 5, 2),
      updatedAt: DateTime(2026, 5, 2),
      sellerName: 'Kibuye Agrovet',
      availableQuantity: 30,
    );

    test(
      'marketplace follow-up and re-scope resolve to marketplace listings',
      () async {
        final List<Listing> listings = <Listing>[
          listingFor('lst_a', 'Fresh Maize'),
          listingFor('lst_b', 'Beans'),
        ];
        final List<String?> searches = <String?>[];
        final f = _contextFixture(
          marketplaceInputs: MarketplaceCapabilityInputs(
            loadListings: ({String? searchQuery}) async {
              searches.add(searchQuery);
              if (searchQuery == null) return listings;
              return listings
                  .where(
                    (Listing l) => l.title.toLowerCase().contains(searchQuery),
                  )
                  .toList(growable: false);
            },
          ),
        );
        final FarmerAdvisorController controller = f.container.read(
          farmerAdvisorControllerProvider.notifier,
        );

        await controller.ask(
          'What is in FAMHUB Marketplace?',
          assistantContext: onMarketplace,
        );
        await _drain();
        await controller.ask(
          'Do we have any maize?',
          assistantContext: onMarketplace,
        );
        await _drain();
        await controller.ask(
          'I mean in marketplace.',
          assistantContext: onMarketplace,
        );
        await _drain();

        // The gateway always receives the farmer's own words — the routing
        // annotation never leaves the client.
        expect(f.gateway.questions, <String>[
          'What is in FAMHUB Marketplace?',
          'Do we have any maize?',
          'I mean in marketplace.',
        ]);
        expect(searches, <String?>[null, 'maize', null]);
        for (final Map<String, dynamic>? evidence
            in f.gateway.capabilityEvidences) {
          expect(evidence, isNotNull);
          expect(evidence!['capability'], kMarketplaceCapabilityId);
        }

        // Turn 2 shipped only the maize listing, with its search stated.
        final Map<String, dynamic> followUp = f.gateway.capabilityEvidences[1]!;
        expect(followUp['searched_for'], 'maize');
        expect(
          (followUp['listings'] as List)
              .map((dynamic r) => (r as Map<String, dynamic>)['title'])
              .toList(),
          <String>['Fresh Maize'],
        );

        // Redacted: no listing, entity, stock or variant ids anywhere.
        final String evidenceJson = jsonEncode(f.gateway.capabilityEvidences);
        expect(evidenceJson, isNot(contains('lst_')));
        expect(evidenceJson, isNot(contains('ent_secret')));
        expect(evidenceJson, isNot(contains('stk_secret')));

        // The stateless gateway is briefed on the active subject and prior turns.
        final Map<String, dynamic> conversation = f.gateway.conversations[1]!;
        expect(conversation['active_subject'], 'marketplace');
        expect((conversation['turns'] as List).first, <String, String>{
          'role': 'farmer',
          'text': 'What is in FAMHUB Marketplace?',
        });

        expect(
          f.container.read(farmerAdvisorControllerProvider).status,
          AdvisorStatus.ready,
        );
      },
    );

    test(
      'feeding dates are retrieved and absent health records stay honest',
      () async {
        final f = _contextFixture(
          livestockInputs: FarmLivestockInputs(
            farms: const <FarmEntity>[
              FarmEntity(
                id: 'f1',
                farmName: 'Kibuye Farm',
                isActive: true,
                isVerified: true,
              ),
            ],
            loadLivestock: (String farmId) async => <LivestockEntity>[
              LivestockEntity(
                id: 'as1',
                farmId: farmId,
                variantId: 'v1',
                species: 'Dairy Fresian',
                breed: 'Fresian',
                count: 12,
                notes: 'Private note, contact 0711 999 000',
                createdAt: DateTime(2026, 1, 1),
              ),
            ],
            loadFields: (String farmId) async => const <FieldEntity>[],
            loadTaxonomy: () async => <LivestockTaxonomyEntry>[
              (variantId: 'v1', itemName: 'dairy', categoryName: 'cattle'),
            ],
            loadActivities: (String farmId) async => <ActivityModel>[
              ActivityModel(
                id: 'act_feed_1',
                activityTypeId: 't1',
                performedAt: DateTime(2026, 3, 5, 9),
                assetId: 'as1',
                notes: 'Private note, contact 0711 999 000',
              ),
            ],
            loadActivityTypeNames: () async => <String, String>{
              't1': 'Feeding',
            },
            loadProduction: (String farmId) async => const <ProductionEntity>[],
            loadCommodities: () async => const <String, String>{},
            loadUnits: () async => const <String, String>{},
          ),
        );

        await _ask(f.container, 'When did we last feed the cattle?');
        await _drain();

        final Map<String, dynamic>? evidence =
            f.gateway.capabilityEvidences.single;
        expect(evidence, isNotNull);
        // The activity gate must not swallow it: the animal-scoped livestock
        // capability owns feeding history.
        expect(evidence!['capability'], 'farm_livestock_context');

        final List<dynamic> care = evidence['recorded_care_events'] as List;
        expect(care, hasLength(1));
        final Map<String, dynamic> feeding =
            care.single as Map<String, dynamic>;
        expect(feeding['type'], 'Feeding');
        expect(
          (feeding['performed_at'] as String).startsWith('2026-03-05'),
          isTrue,
        );
        expect(feeding['animal'], 'Dairy Fresian');

        // No health/vaccination record exists — and the evidence says so
        // without pretending care never happened.
        final String evidenceJson = jsonEncode(evidence);
        expect(evidenceJson, isNot(contains('Vaccin')));
        expect(
          evidence['records_caveat'] as String,
          contains('never that an animal was not vaccinated'),
        );

        // Redaction: no activity id, no private note.
        expect(evidenceJson, isNot(contains('act_feed_1')));
        expect(evidenceJson, isNot(contains('0711')));
        expect(f.gateway.questions.single, 'When did we last feed the cattle?');
      },
    );

    test(
      'a weather question retrieves the farm forecast on any module',
      () async {
        final f = _contextFixture(
          weatherInputs: const FarmWeatherInputs(
            farms: <FarmEntity>[
              FarmEntity(
                id: 'f1',
                farmName: 'Kibuye Farm',
                wardId: 'w1',
                isActive: true,
                isVerified: true,
              ),
            ],
          ),
          weatherService: _FakeWeatherService(bundle: _forecastBundle),
        );

        // Asked while the shell sits on Marketplace: the module is a signal,
        // not a restriction.
        await f.container
            .read(farmerAdvisorControllerProvider.notifier)
            .ask(
              "What's the weather forecast this week?",
              assistantContext: onMarketplace,
            );
        await _drain();

        final Map<String, dynamic>? evidence =
            f.gateway.capabilityEvidences.single;
        expect(evidence, isNotNull);
        expect(evidence!['capability'], 'farm_weather');
        expect(evidence['location_label'], 'Kibuye Farm');
        expect(evidence['scope'], 'forecast');
        final Map<String, dynamic> forecast =
            evidence['forecast']! as Map<String, dynamic>;
        expect(forecast['daily'], isNotEmpty);
        expect(
          f.gateway.questions.single,
          "What's the weather forecast this week?",
        );
      },
    );

    test(
      'a clear topic change moves the conversation between modules',
      () async {
        final List<Listing> listings = <Listing>[
          listingFor('lst_a', 'Fresh Maize'),
        ];
        final f = _contextFixture(
          weatherInputs: const FarmWeatherInputs(
            farms: <FarmEntity>[
              FarmEntity(
                id: 'f1',
                farmName: 'Kibuye Farm',
                wardId: 'w1',
                isActive: true,
                isVerified: true,
              ),
            ],
          ),
          weatherService: _FakeWeatherService(bundle: _forecastBundle),
          marketplaceInputs: MarketplaceCapabilityInputs(
            loadListings: ({String? searchQuery}) async => listings,
          ),
        );
        final FarmerAdvisorController controller = f.container.read(
          farmerAdvisorControllerProvider.notifier,
        );

        // Marketplace → weather, still on the marketplace route.
        await controller.ask(
          'What is in FAMHUB Marketplace?',
          assistantContext: onMarketplace,
        );
        await _drain();
        await controller.ask(
          "What's the weather forecast this week?",
          assistantContext: onMarketplace,
        );
        await _drain();
        // Explicit marketplace again, now from the farm module.
        await controller.ask(
          'What is in FAMHUB Marketplace?',
          assistantContext: _assistantContext,
        );
        await _drain();

        expect(
          f.gateway.capabilityEvidences
              .map((Map<String, dynamic>? e) => e!['capability'])
              .toList(),
          <String>[
            kMarketplaceCapabilityId,
            'farm_weather',
            kMarketplaceCapabilityId,
          ],
        );
        expect(f.gateway.callCount, 3);
      },
    );

    test(
      'ordinary follow-ups reach the gateway with the recent conversation',
      () async {
        final f = _fixture();
        final FarmerAdvisorController controller = f.container.read(
          farmerAdvisorControllerProvider.notifier,
        );

        await controller.ask(
          'Why are my maize leaves yellow?',
          assistantContext: _assistantContext,
        );
        await _drain();
        await controller.ask(
          'And what about the yellowing on the lower leaves?',
          assistantContext: _assistantContext,
        );
        await _drain();

        expect(f.gateway.callCount, 2);
        // The farmer's own words verbatim — never the routing annotation.
        expect(
          f.gateway.questions[1],
          'And what about the yellowing on the lower leaves?',
        );

        // First turn: subject from the module, no prior turns.
        final Map<String, dynamic> first = f.gateway.conversations[0]!;
        expect(first['active_subject'], 'farm');
        expect(first.containsKey('turns'), isFalse);

        // Follow-up: the prior exchange travels with the request.
        final Map<String, dynamic> second = f.gateway.conversations[1]!;
        expect(second['active_subject'], 'farm');
        expect((second['turns'] as List).first, <String, String>{
          'role': 'farmer',
          'text': 'Why are my maize leaves yellow?',
        });
      },
    );
  });

  group('persistent chat history', () {
    test(
      'loads the saved conversation list when the controller starts',
      () async {
        final InMemoryAssistantChatRepository chat =
            InMemoryAssistantChatRepository(
              seedConversations: <AssistantConversation>[
                AssistantConversation(
                  id: 'conv-1',
                  title: 'Soil advice',
                  createdAt: DateTime(2026, 10, 17),
                  lastMessageAt: DateTime(2026, 10, 18),
                  contextMetadata: <String, dynamic>{'current_page': '/farm'},
                ),
              ],
            );
        final f = _fixture(chat: chat);
        // First read builds the controller and schedules the restore.
        f.container.read(farmerAdvisorControllerProvider);
        await _drain();

        final FarmerAdvisorState state = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(state.historyStatus, AdvisorHistoryStatus.ready);
        expect(state.conversations, hasLength(1));
        expect(state.conversations.single.title, 'Soil advice');
        // Nothing was selected yet, so no thread is silently opened.
        expect(state.activeConversationId, isNull);
        expect(state.isEmpty, isTrue);
      },
    );

    test(
      'a failed history load is reported, never shown as empty success',
      () async {
        final InMemoryAssistantChatRepository chat =
            InMemoryAssistantChatRepository(
              seedConversations: <AssistantConversation>[
                AssistantConversation(
                  id: 'conv-1',
                  title: 'Soil advice',
                  createdAt: DateTime(2026, 10, 17),
                ),
              ],
            )..failFetchConversations = true;
        final f = _fixture(chat: chat);
        f.container.read(farmerAdvisorControllerProvider);
        await _drain();

        expect(
          f.container.read(farmerAdvisorControllerProvider).historyStatus,
          AdvisorHistoryStatus.failure,
        );

        chat.failFetchConversations = false;
        await f.container
            .read(farmerAdvisorControllerProvider.notifier)
            .retryHistoryLoad();

        final FarmerAdvisorState state = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(state.historyStatus, AdvisorHistoryStatus.ready);
        expect(state.conversations, hasLength(1));
        expect(state.managementError, isNull);
      },
    );

    test(
      'first committed turn creates a titled conversation with label-only metadata',
      () async {
        final f = _fixture();
        f.container.read(farmerAdvisorControllerProvider);
        await _drain();

        await _ask(f.container, 'When was my cow vaccinated?');
        await _drain();

        final FarmerAdvisorState state = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(state.activeConversationId, isNotNull);
        expect(state.conversations, hasLength(1));

        final AssistantConversation created = f.chat.conversations.single;
        expect(created.title, 'When was my cow vaccinated?');
        // Module/route/workspace LABELS only — never ids.
        expect(created.contextMetadata['current_page'], '/farm');
        expect(created.contextMetadata['current_module'], 'Farm Management');
        expect(created.contextMetadata['active_workspace'], 'Kibuye Farm');
        expect(
          jsonEncode(created.contextMetadata),
          isNot(contains('farm_management')),
        );

        // Farmer line first, adviser line second — written exactly once.
        expect(f.chat.writes, hasLength(2));
        expect(f.chat.writes.first.role, 'farmer');
        expect(f.chat.writes.first.text, 'When was my cow vaccinated?');
        expect(f.chat.writes.last.role, 'adviser');
        expect(f.prefs.lastId, state.activeConversationId);
        expect(state.persistenceFailed, isFalse);
        expect(state.unsavedMessageCount, 0);
      },
    );

    test('a conversation title over 60 characters is bounded', () async {
      const String long =
          'Why are the leaves on my maize turning yellow at the tips after the rain?';
      final f = _fixture();
      f.container.read(farmerAdvisorControllerProvider);
      await _drain();
      await _ask(f.container, long);
      await _drain();

      final AssistantConversation created = f.chat.conversations.single;
      expect(created.title.length, 60);
      expect(created.title.endsWith('…'), isTrue);
    });

    test('a conversation survives a full app restart', () async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository();
      final InMemoryAssistantChatPreferences prefs =
          InMemoryAssistantChatPreferences();

      final first = _fixture(chat: chat, prefs: prefs);
      first.container.read(farmerAdvisorControllerProvider);
      await _drain();
      await _ask(first.container, 'My maize leaves are yellow.');
      await _drain();
      final String savedId = first.container
          .read(farmerAdvisorControllerProvider)
          .activeConversationId!;
      expect(savedId, isNotNull);
      expect(chat.writes, hasLength(2));

      // "Restart": a brand-new container over the same storage.
      final restarted = _fixture(chat: chat, prefs: prefs);
      restarted.container.read(farmerAdvisorControllerProvider);
      await _drain();

      final FarmerAdvisorState state = restarted.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.historyStatus, AdvisorHistoryStatus.ready);
      expect(state.activeConversationId, savedId);
      expect(state.messages, hasLength(2));
      expect(state.messages.first.isFarmer, isTrue);
      expect(state.messages.first.text, 'My maize leaves are yellow.');
      expect(state.messages.last.isFarmer, isFalse);
      expect(state.conversations, hasLength(1));
      // Restoring reads — it never re-writes the stored turn.
      expect(chat.writes, hasLength(2));
    });

    test(
      'a restore never steals the active thread from a question asked while it loads',
      () async {
        final InMemoryAssistantChatRepository chat =
            InMemoryAssistantChatRepository(
              seedConversations: <AssistantConversation>[
                AssistantConversation(
                  id: 'conv-seeded',
                  title: 'Seeded thread',
                  createdAt: DateTime(2026, 10, 17),
                ),
              ],
            );
        final InMemoryAssistantChatPreferences prefs =
            InMemoryAssistantChatPreferences(lastConversationId: 'conv-seeded');
        final f = _fixture(chat: chat, prefs: prefs);
        f.container.read(farmerAdvisorControllerProvider);
        // Ask before the restore's microtask chain finishes.
        await _ask(f.container, 'Question asked during restore?');
        await _drain();

        final FarmerAdvisorState state = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(state.messages, hasLength(2));
        expect(state.messages.first.text, 'Question asked during restore?');
        // The thread that turn landed in is the new one, not the seeded one.
        expect(state.activeConversationId, isNotNull);
        expect(state.activeConversationId, isNot('conv-seeded'));
        expect(
          state.conversations.map((AssistantConversation c) => c.id),
          contains('conv-seeded'),
        );
      },
    );

    test(
      'a persistence failure is visible and retried without losing the turn',
      () async {
        final InMemoryAssistantChatRepository chat =
            InMemoryAssistantChatRepository()..failAppend = true;
        final f = _fixture(chat: chat);
        f.container.read(farmerAdvisorControllerProvider);
        await _drain();

        await _ask(f.container, 'Is my soil acidic?');
        await _drain();

        FarmerAdvisorState state = f.container.read(
          farmerAdvisorControllerProvider,
        );
        // The answer is never withheld because storage failed.
        expect(state.messages, hasLength(2));
        expect(state.persistenceFailed, isTrue);
        expect(state.persistenceWarning, isTrue);
        expect(state.unsavedMessageCount, 2);
        expect(chat.writes, isEmpty);

        chat.failAppend = false;
        await f.container
            .read(farmerAdvisorControllerProvider.notifier)
            .retryPersistence();

        state = f.container.read(farmerAdvisorControllerProvider);
        expect(state.persistenceFailed, isFalse);
        expect(state.persistenceWarning, isFalse);
        expect(state.unsavedMessageCount, 0);
        expect(chat.writes, hasLength(2));
        expect(chat.writes.first.text, 'Is my soil acidic?');
      },
    );

    test('queued turns flush in order once storage recovers', () async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository()..failAppend = true;
      final f = _fixture(chat: chat);
      f.container.read(farmerAdvisorControllerProvider);
      await _drain();

      await _ask(f.container, 'First question?');
      await _drain();
      await _ask(f.container, 'Second question?');
      await _drain();

      FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.unsavedMessageCount, 4);
      expect(state.persistenceFailed, isTrue);
      expect(chat.writes, isEmpty);

      chat.failAppend = false;
      await f.container
          .read(farmerAdvisorControllerProvider.notifier)
          .retryPersistence();

      state = f.container.read(farmerAdvisorControllerProvider);
      expect(state.unsavedMessageCount, 0);
      expect(state.persistenceFailed, isFalse);
      expect(chat.writes.map((w) => w.text).toList(), <String>[
        'First question?',
        'Keep observing the leaves and share a photo.',
        'Second question?',
        'Keep observing the leaves and share a photo.',
      ]);
      expect(chat.writes.map((w) => w.role).toList(), <String>[
        'farmer',
        'adviser',
        'farmer',
        'adviser',
      ]);
      // Both turns landed in the same conversation.
      expect(chat.writes.map((w) => w.conversationId).toSet(), hasLength(1));
    });

    test('a failed gateway turn is not persisted until it completes', () async {
      final f = _fixture();
      f.container.read(farmerAdvisorControllerProvider);
      await _drain();

      f.gateway.scriptFailureThenSuccess();
      await _ask(f.container, 'Is my soil acidic?');
      await _drain();

      FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.status, AdvisorStatus.failure);
      expect(f.chat.writes, isEmpty);
      expect(f.chat.conversations, isEmpty);
      expect(state.conversations, isEmpty);
      expect(state.persistenceFailed, isFalse);

      // Retry completes the same turn — then (and only then) it is stored.
      f.gateway.result = null;
      await f.container.read(farmerAdvisorControllerProvider.notifier).retry();
      await _drain();

      state = f.container.read(farmerAdvisorControllerProvider);
      expect(state.status, AdvisorStatus.ready);
      expect(state.messages, hasLength(2));
      expect(f.chat.writes, hasLength(2));
      expect(f.chat.writes.first.text, 'Is my soil acidic?');
      expect(state.conversations, hasLength(1));
    });

    test('new chat detaches but keeps the previous conversation', () async {
      final f = _fixture();
      f.container.read(farmerAdvisorControllerProvider);
      await _drain();
      await _ask(f.container, 'Question one?');
      await _drain();
      final String firstId = f.container
          .read(farmerAdvisorControllerProvider)
          .activeConversationId!;

      final FarmerAdvisorController controller = f.container.read(
        farmerAdvisorControllerProvider.notifier,
      );
      controller.startNewChat();
      await _drain();

      FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.activeConversationId, isNull);
      expect(state.isEmpty, isTrue);
      expect(state.status, AdvisorStatus.ready);
      expect(
        state.conversations.map((AssistantConversation c) => c.id),
        contains(firstId),
      );
      expect(f.prefs.lastId, isNull);

      await _ask(f.container, 'Question two?');
      await _drain();
      state = f.container.read(farmerAdvisorControllerProvider);
      expect(state.conversations, hasLength(2));
      expect(state.activeConversationId, isNot(firstId));
      expect(f.chat.writes, hasLength(4));
      expect(f.chat.conversations, hasLength(2));
    });

    test('rename updates the saved list and ignores an empty title', () async {
      final f = _fixture();
      f.container.read(farmerAdvisorControllerProvider);
      await _drain();
      await _ask(f.container, 'Question one?');
      await _drain();
      final String activeId = f.container
          .read(farmerAdvisorControllerProvider)
          .activeConversationId!;
      final FarmerAdvisorController controller = f.container.read(
        farmerAdvisorControllerProvider.notifier,
      );

      await controller.renameConversation(activeId, '  Herd health plan  ');
      expect(
        f.container.read(farmerAdvisorControllerProvider).conversations,
        hasLength(1),
      );
      expect(
        f.container
            .read(farmerAdvisorControllerProvider)
            .conversations
            .single
            .title,
        'Herd health plan',
      );
      expect(f.chat.conversations.single.title, 'Herd health plan');

      // Whitespace-only renames are ignored entirely.
      await controller.renameConversation(activeId, '   ');
      expect(f.chat.conversations.single.title, 'Herd health plan');

      // Titles are bounded at 80 characters.
      await controller.renameConversation(activeId, 'x' * 100);
      expect(f.chat.conversations.single.title.length, 80);
      expect(
        f.container
            .read(farmerAdvisorControllerProvider)
            .conversations
            .single
            .title,
        'x' * 80,
      );
      expect(
        f.container.read(farmerAdvisorControllerProvider).managementError,
        isNull,
      );
    });

    test('a rename failure surfaces as a management error', () async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository()..failRename = true;
      final f = _fixture(chat: chat);
      f.container.read(farmerAdvisorControllerProvider);
      await _drain();
      await _ask(f.container, 'Question one?');
      await _drain();
      final String activeId = f.container
          .read(farmerAdvisorControllerProvider)
          .activeConversationId!;

      await f.container
          .read(farmerAdvisorControllerProvider.notifier)
          .renameConversation(activeId, 'Renamed');

      expect(
        f.container.read(farmerAdvisorControllerProvider).managementError,
        'rename_failed',
      );
      // The original title is untouched.
      expect(f.chat.conversations.single.title, 'Question one?');
    });

    test('deleting the active conversation starts a fresh chat', () async {
      final f = _fixture();
      f.container.read(farmerAdvisorControllerProvider);
      await _drain();
      await _ask(f.container, 'Question one?');
      await _drain();
      final String activeId = f.container
          .read(farmerAdvisorControllerProvider)
          .activeConversationId!;

      await f.container
          .read(farmerAdvisorControllerProvider.notifier)
          .deleteConversation(activeId);
      await _drain();

      final FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.activeConversationId, isNull);
      expect(state.isEmpty, isTrue);
      expect(state.conversations, isEmpty);
      expect(f.chat.conversations, isEmpty);
      expect(f.prefs.lastId, isNull);
      expect(state.managementError, isNull);
    });

    test(
      'deleting a background conversation keeps the active thread open',
      () async {
        final f = _fixture();
        f.container.read(farmerAdvisorControllerProvider);
        await _drain();
        await _ask(f.container, 'Question one?');
        await _drain();
        final String firstId = f.container
            .read(farmerAdvisorControllerProvider)
            .activeConversationId!;

        final FarmerAdvisorController controller = f.container.read(
          farmerAdvisorControllerProvider.notifier,
        );
        controller.startNewChat();
        await _drain();
        await _ask(f.container, 'Question two?');
        await _drain();

        FarmerAdvisorState state = f.container.read(
          farmerAdvisorControllerProvider,
        );
        final String activeId = state.activeConversationId!;
        expect(state.conversations, hasLength(2));

        await controller.deleteConversation(firstId);
        await _drain();

        state = f.container.read(farmerAdvisorControllerProvider);
        expect(state.activeConversationId, activeId);
        expect(state.messages, hasLength(2));
        expect(state.messages.first.text, 'Question two?');
        expect(state.conversations, hasLength(1));
        expect(state.conversations.single.id, activeId);
        expect(f.prefs.lastId, activeId);
      },
    );

    test('a delete failure surfaces as a management error', () async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository()..failDelete = true;
      final f = _fixture(chat: chat);
      f.container.read(farmerAdvisorControllerProvider);
      await _drain();
      await _ask(f.container, 'Question one?');
      await _drain();
      final String activeId = f.container
          .read(farmerAdvisorControllerProvider)
          .activeConversationId!;

      await f.container
          .read(farmerAdvisorControllerProvider.notifier)
          .deleteConversation(activeId);

      expect(
        f.container.read(farmerAdvisorControllerProvider).managementError,
        'delete_failed',
      );
      expect(
        f.container.read(farmerAdvisorControllerProvider).conversations,
        hasLength(1),
      );
      expect(f.chat.conversations, hasLength(1));
    });

    test('opening a saved conversation restores its stored messages', () async {
      final InMemoryAssistantChatRepository chat =
          InMemoryAssistantChatRepository(
            seedConversations: <AssistantConversation>[
              AssistantConversation(
                id: 'conv-1',
                title: 'Soil advice',
                createdAt: DateTime(2026, 10, 17),
              ),
            ],
            seedMessages: <String, List<AssistantChatMessage>>{
              'conv-1': <AssistantChatMessage>[
                AssistantChatMessage(
                  id: 'm-1',
                  conversationId: 'conv-1',
                  role: 'farmer',
                  text: 'pH is low?',
                  createdAt: DateTime(2026, 10, 17, 10),
                ),
                AssistantChatMessage(
                  id: 'm-2',
                  conversationId: 'conv-1',
                  role: 'adviser',
                  text: 'Add lime gradually and re-test in a season.',
                  createdAt: DateTime(2026, 10, 17, 10, 1),
                ),
              ],
            },
          );
      final f = _fixture(chat: chat);
      f.container.read(farmerAdvisorControllerProvider);
      await _drain();
      expect(f.container.read(farmerAdvisorControllerProvider).isEmpty, isTrue);

      await f.container
          .read(farmerAdvisorControllerProvider.notifier)
          .selectConversation('conv-1');

      final FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.activeConversationId, 'conv-1');
      expect(state.openingConversation, isFalse);
      expect(state.openConversationFailed, isFalse);
      expect(state.messages, hasLength(2));
      expect(state.messages.first.isFarmer, isTrue);
      expect(state.messages.first.text, 'pH is low?');
      expect(state.messages.last.isFarmer, isFalse);
      expect(state.status, AdvisorStatus.ready);
      expect(f.prefs.lastId, 'conv-1');
    });

    test(
      'a failed open reports honestly and keeps the current thread',
      () async {
        final InMemoryAssistantChatRepository chat =
            InMemoryAssistantChatRepository(
              seedConversations: <AssistantConversation>[
                AssistantConversation(
                  id: 'conv-1',
                  title: 'Soil advice',
                  createdAt: DateTime(2026, 10, 17),
                ),
              ],
            )..failFetchMessages = true;
        final f = _fixture(chat: chat);
        f.container.read(farmerAdvisorControllerProvider);
        await _drain();

        await f.container
            .read(farmerAdvisorControllerProvider.notifier)
            .selectConversation('conv-1');

        final FarmerAdvisorState state = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(state.openConversationFailed, isTrue);
        expect(state.openingConversation, isFalse);
        expect(state.activeConversationId, isNull);
        expect(state.isEmpty, isTrue);
        expect(f.prefs.lastId, isNull);
      },
    );
  });

  // ══════════════════════════════════════════════════════════
  // Clarification continuity — the pending-question fix. A short reply
  // ("Green valley", "the second one") must resume the ORIGINAL request
  // through the capability that asked it, with farm-scoped,
  // repository-verified data. Real production composition throughout;
  // only the data seams are faked.
  // ══════════════════════════════════════════════════════════
  group('clarification continuity', () {
    const String originalQuestion =
        'What activities have been recorded on my farm?';

    const FarmEntity gold = FarmEntity(
      id: 'f_gold',
      farmName: 'Gold Farm',
      isActive: true,
      isVerified: true,
    );
    const FarmEntity green = FarmEntity(
      id: 'f_green',
      farmName: 'Green Valley',
      isActive: true,
      isVerified: true,
    );

    /// Two-farm activity seam that records every farm whose rows were
    /// read. Only Green Valley keeps a feeding record, only Gold Farm a
    /// spraying record — so the evidence proves which farm answered.
    ({FarmActivityInputs inputs, List<String> requests}) activitySeam({
      bool greenHasRecords = true,
    }) {
      final List<String> requests = <String>[];
      return (
        inputs: FarmActivityInputs(
          farms: const <FarmEntity>[gold, green],
          loadActivities: (String farmId) async {
            requests.add(farmId);
            if (farmId != 'f_green') {
              return <ActivityModel>[
                ActivityModel(
                  id: 'act_spray_gold',
                  activityTypeId: 't2',
                  performedAt: DateTime(2026, 10, 10, 9),
                ),
              ];
            }
            if (!greenHasRecords) return const <ActivityModel>[];
            return <ActivityModel>[
              ActivityModel(
                id: 'act_feed_green',
                activityTypeId: 't1',
                performedAt: DateTime(2026, 10, 12, 9),
              ),
            ];
          },
          loadActivityTypeNames: () async => const <String, String>{
            't1': 'Feeding',
            't2': 'Spraying',
          },
          loadAssets: (String farmId) async => const <AssetEntity>[],
          loadFields: (String farmId) async => const <FieldEntity>[],
        ),
        requests: requests,
      );
    }

    /// Stub that asks one farm clarification and then serves evidence for
    /// the resumed run (plus a spare for a retry).
    _StubCapability continuityStub() {
      final _StubCapability capability = _StubCapability(
        id: kFarmActivityCapabilityId,
        isMatch: (String question) => true,
        outcome: const AssistantCapabilityOutcome.clarification(
          capabilityId: kFarmActivityCapabilityId,
          text:
              'Which farm do you mean? I can see: Gold Farm or Green '
              'Valley.',
          options: <String>['Gold Farm', 'Green Valley'],
        ),
      );
      capability.scriptedOutcomes
        ..add(capability.outcome)
        ..add(
          const AssistantCapabilityOutcome.evidence(
            capabilityId: kFarmActivityCapabilityId,
            evidence: <String, dynamic>{
              'capability': kFarmActivityCapabilityId,
            },
          ),
        )
        ..add(
          const AssistantCapabilityOutcome.evidence(
            capabilityId: kFarmActivityCapabilityId,
            evidence: <String, dynamic>{
              'capability': kFarmActivityCapabilityId,
            },
          ),
        );
      return capability;
    }

    test(
      'a short farm answer resumes the original request farm-scoped',
      () async {
        final seam = activitySeam();
        final f = _contextFixture(activityInputs: seam.inputs);
        f.gateway.result = const AiGatewayResult.success(
          elapsed: Duration(milliseconds: 12),
          statusCode: 200,
          requestId: 'req-test',
          output: 'Green Valley has one recorded feeding activity.',
        );

        // Turn 1: the capability asks which farm; the model is not
        // called and no repository row is read yet.
        await _ask(f.container, originalQuestion);
        await _drain();

        expect(f.gateway.callCount, 0);
        final FarmerAdvisorState asking = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(asking.status, AdvisorStatus.ready);
        expect(asking.messages.last.isFarmer, isFalse);
        expect(asking.messages.last.text, contains('Which farm do you mean'));
        expect(asking.messages.last.text, contains('Green Valley'));
        expect(seam.requests, isEmpty);

        // Turn 2: the reply alone resumes the SAME capability on the
        // original request, scoped to Green Valley's rows only.
        await _ask(f.container, 'Green valley');
        await _drain();

        expect(f.gateway.questions, <String>['Green valley']);
        final Map<String, dynamic>? evidence =
            f.gateway.capabilityEvidences.single;
        expect(evidence, isNotNull);
        expect(evidence!['capability'], kFarmActivityCapabilityId);
        expect(
          (evidence['farm']! as Map<String, dynamic>)['name'],
          'Green Valley',
        );
        expect(
          (evidence['activities'] as List)
              .map((dynamic row) => (row as Map<String, dynamic>)['type'])
              .toList(),
          <String>['Feeding'],
        );

        // Repository-verified: Green Valley's rows were read, Gold Farm's
        // spraying record was never touched, and no ids leaked.
        expect(seam.requests, <String>['f_green']);
        final String evidenceJson = jsonEncode(evidence);
        expect(evidenceJson, isNot(contains('Spraying')));
        expect(evidenceJson, isNot(contains('f_green')));
        expect(evidenceJson, isNot(contains('act_feed_green')));

        final FarmerAdvisorState answered = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(answered.status, AdvisorStatus.ready);
        expect(
          answered.messages.last.text,
          'Green Valley has one recorded feeding activity.',
        );
      },
    );

    test('the other offered farm resumes against its own records', () async {
      final seam = activitySeam();
      final f = _contextFixture(activityInputs: seam.inputs);
      f.gateway.result = const AiGatewayResult.success(
        elapsed: Duration(milliseconds: 12),
        statusCode: 200,
        requestId: 'req-test',
        output: 'Gold Farm has one recorded spraying activity.',
      );

      await _ask(f.container, originalQuestion);
      await _drain();
      await _ask(f.container, 'Gold Farm');
      await _drain();

      expect(f.gateway.questions, <String>['Gold Farm']);
      final Map<String, dynamic>? evidence =
          f.gateway.capabilityEvidences.single;
      expect(evidence, isNotNull);
      expect(evidence!['capability'], kFarmActivityCapabilityId);
      expect((evidence['farm']! as Map<String, dynamic>)['name'], 'Gold Farm');
      expect(
        (evidence['activities'] as List)
            .map((dynamic row) => (row as Map<String, dynamic>)['type'])
            .toList(),
        <String>['Spraying'],
      );
      expect(seam.requests, <String>['f_gold']);
      expect(jsonEncode(evidence), isNot(contains('Feeding')));
    });

    test('the offered farm name matches in any casing', () async {
      final seam = activitySeam();
      final f = _contextFixture(activityInputs: seam.inputs);

      await _ask(f.container, originalQuestion);
      await _drain();
      await _ask(f.container, 'GrEen VaLLeY');
      await _drain();

      expect(f.gateway.questions, <String>['GrEen VaLLeY']);
      final Map<String, dynamic>? evidence =
          f.gateway.capabilityEvidences.single;
      expect(evidence, isNotNull);
      expect(evidence!['capability'], kFarmActivityCapabilityId);
      expect(
        (evidence['farm']! as Map<String, dynamic>)['name'],
        'Green Valley',
      );
      expect(seam.requests, <String>['f_green']);
    });

    test(
      'a positional answer picks the option that was actually offered',
      () async {
        final seam = activitySeam();
        final f = _contextFixture(activityInputs: seam.inputs);

        await _ask(f.container, originalQuestion);
        await _drain();
        await _ask(f.container, 'the second one');
        await _drain();

        // Options were offered in farm order: Gold Farm, Green Valley.
        expect(f.gateway.questions, <String>['the second one']);
        final Map<String, dynamic>? evidence =
            f.gateway.capabilityEvidences.single;
        expect(evidence, isNotNull);
        expect(evidence!['capability'], kFarmActivityCapabilityId);
        expect(
          (evidence['farm']! as Map<String, dynamic>)['name'],
          'Green Valley',
        );
        expect(seam.requests, <String>['f_green']);
      },
    );

    test('an unoffered answer re-asks without the gateway and the task '
        'survives', () async {
      final seam = activitySeam();
      final f = _contextFixture(activityInputs: seam.inputs);
      f.gateway.result = const AiGatewayResult.success(
        elapsed: Duration(milliseconds: 12),
        statusCode: 200,
        requestId: 'req-test',
        output: 'Green Valley has one recorded feeding activity.',
      );

      await _ask(f.container, originalQuestion);
      await _drain();
      await _ask(f.container, 'Blue Farm');
      await _drain();

      // "Blue Farm" maps to nothing offered: re-clarified from the
      // still-open task, with no rows read and no model consulted.
      expect(f.gateway.callCount, 0);
      final FarmerAdvisorState reasking = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(reasking.status, AdvisorStatus.ready);
      expect(reasking.messages.last.isFarmer, isFalse);
      expect(reasking.messages.last.text, contains('Which farm do you mean'));
      expect(seam.requests, isEmpty);

      // The original request is still open and now completes.
      await _ask(f.container, 'Green valley');
      await _drain();

      expect(f.gateway.questions, <String>['Green valley']);
      final Map<String, dynamic>? evidence =
          f.gateway.capabilityEvidences.single;
      expect(evidence, isNotNull);
      expect(evidence!['capability'], kFarmActivityCapabilityId);
      expect(
        (evidence['farm']! as Map<String, dynamic>)['name'],
        'Green Valley',
      );
      expect(seam.requests, <String>['f_green']);
    });

    test('an answered farm with no records stays honest and scoped', () async {
      final seam = activitySeam(greenHasRecords: false);
      final f = _contextFixture(activityInputs: seam.inputs);

      await _ask(f.container, originalQuestion);
      await _drain();
      await _ask(f.container, 'Green valley');
      await _drain();

      // Never invented: the model was not consulted, and Gold Farm's
      // records were not substituted for Green Valley's missing rows.
      expect(f.gateway.callCount, 0);
      expect(seam.requests, <String>['f_green']);
      final FarmerAdvisorState state = f.container.read(
        farmerAdvisorControllerProvider,
      );
      expect(state.status, AdvisorStatus.ready);
      expect(state.messages.last.isFarmer, isFalse);
      expect(
        state.messages.last.text,
        contains('nothing matching is recorded here'),
      );
      expect(
        state.messages.last.text,
        contains('not that the work was never done'),
      );
    });

    test(
      'a clear new question replaces the open task instead of trapping it',
      () async {
        final seam = activitySeam();
        final f = _contextFixture(
          activityInputs: seam.inputs,
          weatherInputs: const FarmWeatherInputs(
            farms: <FarmEntity>[
              FarmEntity(
                id: 'f_weather',
                farmName: 'Kibuye Farm',
                wardId: 'w1',
                isActive: true,
                isVerified: true,
              ),
            ],
          ),
          weatherService: _FakeWeatherService(bundle: _forecastBundle),
        );

        await _ask(f.container, originalQuestion);
        await _drain();
        expect(f.gateway.callCount, 0);

        // The weather question carries a question mark: it is a fresh
        // request, not an answer to "which farm".
        await _ask(f.container, "What's the weather forecast this week?");
        await _drain();

        expect(f.gateway.questions, <String>[
          "What's the weather forecast this week?",
        ]);
        final Map<String, dynamic>? evidence =
            f.gateway.capabilityEvidences.single;
        expect(evidence, isNotNull);
        expect(evidence!['capability'], 'farm_weather');
        expect(evidence['location_label'], 'Kibuye Farm');
        // The pending activity resume never ran.
        expect(seam.requests, isEmpty);
      },
    );

    test(
      'a weather clarification resumes the forecast for the answered farm',
      () async {
        final f = _contextFixture(
          weatherInputs: const FarmWeatherInputs(
            farms: <FarmEntity>[
              FarmEntity(
                id: 'f_gold_w',
                farmName: 'Gold Farm',
                wardId: 'w1',
                isActive: true,
                isVerified: true,
              ),
              FarmEntity(
                id: 'f_green_w',
                farmName: 'Green Valley',
                wardId: 'w2',
                isActive: true,
                isVerified: true,
              ),
            ],
          ),
          weatherService: _FakeWeatherService(bundle: _forecastBundle),
        );

        await _ask(f.container, "What's the weather forecast this week?");
        await _drain();

        expect(f.gateway.callCount, 0);
        final FarmerAdvisorState asking = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(asking.status, AdvisorStatus.ready);
        expect(asking.messages.last.text, contains('Which farm do you mean'));
        expect(asking.messages.last.text, contains('Green Valley'));

        await _ask(f.container, 'Green valley');
        await _drain();

        expect(f.gateway.questions, <String>['Green valley']);
        final Map<String, dynamic>? evidence =
            f.gateway.capabilityEvidences.single;
        expect(evidence, isNotNull);
        expect(evidence!['capability'], 'farm_weather');
        expect(evidence['location_label'], 'Green Valley');
        expect(evidence['scope'], 'forecast');
        expect(
          (evidence['forecast']! as Map<String, dynamic>)['daily'],
          isNotEmpty,
        );
        expect(
          f.container.read(farmerAdvisorControllerProvider).status,
          AdvisorStatus.ready,
        );
      },
    );

    test(
      'the resumed run executes the original question plus the answer',
      () async {
        final _StubCapability capability = continuityStub();
        final f = _fixture(capabilities: <AssistantCapability>[capability]);

        await _ask(f.container, originalQuestion);
        await _drain();
        await _ask(f.container, 'Green valley');
        await _drain();

        // The SAME capability ran twice: first on the farmer's question,
        // then on that original question with the answer composed in —
        // never on the short reply alone.
        expect(capability.runQuestions, <String>[
          originalQuestion,
          '$originalQuestion Green valley',
        ]);
        // The gateway still receives the farmer's own words, verbatim.
        expect(f.gateway.questions, <String>['Green valley']);
        expect(f.gateway.capabilityEvidences.single, <String, dynamic>{
          'capability': kFarmActivityCapabilityId,
        });
        expect(
          f.container.read(farmerAdvisorControllerProvider).status,
          AdvisorStatus.ready,
        );
      },
    );

    test(
      'a failed resumed turn retries with its evidence still attached',
      () async {
        final _StubCapability capability = continuityStub();
        final f = _fixture(capabilities: <AssistantCapability>[capability]);
        f.gateway.scriptFailureThenSuccess();

        await _ask(f.container, originalQuestion);
        await _drain();
        await _ask(f.container, 'Green valley');
        await _drain();

        final FarmerAdvisorState failed = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(failed.status, AdvisorStatus.failure);
        expect(failed.canRetry, isTrue);

        f.gateway.result = const AiGatewayResult.success(
          elapsed: Duration(milliseconds: 12),
          statusCode: 200,
          requestId: 'req-test',
          output: 'Green Valley recorded one feeding activity.',
        );
        await f.container
            .read(farmerAdvisorControllerProvider.notifier)
            .retry();
        await _drain();

        // The retry re-ran the SAME resume, so the model received the
        // evidence instead of a bare short answer.
        expect(capability.runQuestions, <String>[
          originalQuestion,
          '$originalQuestion Green valley',
          '$originalQuestion Green valley',
        ]);
        expect(f.gateway.questions, <String>['Green valley', 'Green valley']);
        expect(f.gateway.capabilityEvidences.last, <String, dynamic>{
          'capability': kFarmActivityCapabilityId,
        });
        final FarmerAdvisorState retried = f.container.read(
          farmerAdvisorControllerProvider,
        );
        expect(retried.status, AdvisorStatus.ready);
        expect(
          retried.messages.last.text,
          'Green Valley recorded one feeding activity.',
        );
      },
    );
  });
}

/// Production composition fixture: only data seams (inputs, weather
/// service, gateway, farm context) are replaced, so capability selection
/// order and provider wiring are exactly what the app runs.
({ProviderContainer container, _FakeGateway gateway}) _contextFixture({
  FarmWeatherInputs weatherInputs = const FarmWeatherInputs(),
  WeatherService? weatherService,
  FarmActivityInputs? activityInputs,
  FarmLivestockInputs? livestockInputs,
  FarmCropInputs? cropInputs,
  MarketplaceCapabilityInputs? marketplaceInputs,
}) {
  final _FakeGateway gateway = _FakeGateway();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      farmerAdvisorGatewayProvider.overrideWithValue(gateway),
      farmAiContextProvider.overrideWithValue(null),
      assistantChatRepositoryProvider.overrideWithValue(
        InMemoryAssistantChatRepository(),
      ),
      assistantChatPreferencesProvider.overrideWithValue(
        InMemoryAssistantChatPreferences(),
      ),
      farmWeatherInputsProvider.overrideWithValue(weatherInputs),
      weatherServiceProvider.overrideWithValue(
        weatherService ?? _FakeWeatherService(bundle: const WeatherBundle()),
      ),
      farmActivityInputsProvider.overrideWithValue(
        activityInputs ??
            FarmActivityInputs(
              loadActivities: (String farmId) async => const <ActivityModel>[],
              loadActivityTypeNames: () async => const <String, String>{},
              loadAssets: (String farmId) async => const <AssetEntity>[],
              loadFields: (String farmId) async => const <FieldEntity>[],
            ),
      ),
      farmLivestockInputsProvider.overrideWithValue(
        livestockInputs ??
            FarmLivestockInputs(
              loadLivestock: (String farmId) async => const <LivestockEntity>[],
              loadFields: (String farmId) async => const <FieldEntity>[],
              loadTaxonomy: () async => const <LivestockTaxonomyEntry>[],
              loadActivities: (String farmId) async => const <ActivityModel>[],
              loadActivityTypeNames: () async => const <String, String>{},
              loadProduction: (String farmId) async =>
                  const <ProductionEntity>[],
              loadCommodities: () async => const <String, String>{},
              loadUnits: () async => const <String, String>{},
            ),
      ),
      farmCropInputsProvider.overrideWithValue(
        cropInputs ??
            FarmCropInputs(
              loadFields: (String farmId) async => const <FieldEntity>[],
              loadCrops: (String farmId, String? fieldId) async =>
                  const <CropEntity>[],
            ),
      ),
      marketplaceCapabilityInputsProvider.overrideWithValue(
        marketplaceInputs ??
            MarketplaceCapabilityInputs(
              loadListings: ({String? searchQuery}) async => const <Listing>[],
            ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, gateway: gateway);
}

/// Stand-in for the deployed `app-weather` client. Never touches the network.
class _FakeWeatherService implements WeatherService {
  _FakeWeatherService({required this.bundle});

  final WeatherBundle bundle;

  @override
  Future<WeatherBundle> fetch({
    required WeatherRequestTarget target,
    required WeatherScope scope,
  }) async {
    return bundle;
  }
}

final WeatherBundle _forecastBundle = WeatherBundle(
  daily: <DailyForecast>[
    DailyForecast(
      date: DateTime(2026, 10, 19),
      condition: 'Light rain',
      tempMaxC: 27,
      tempMinC: 16,
      rainfallMm: 4.1,
    ),
  ],
  meta: WeatherMeta(
    fetchedAt: DateTime(2026, 10, 18, 9, 5),
    scope: WeatherScope.forecast,
  ),
);

/// Minimal capability double: no I/O, no container, no network.
class _StubCapability implements AssistantCapability {
  _StubCapability({
    required this.id,
    required this.isMatch,
    required this.outcome,
    this.throwOnRun = false,
  });

  @override
  final String id;

  final bool Function(String question) isMatch;
  final AssistantCapabilityOutcome outcome;
  final bool throwOnRun;

  int runCount = 0;

  /// Outcomes consumed one per run before [outcome], so a test can script a
  /// clarification followed by the evidence its resumed run produces.
  final List<AssistantCapabilityOutcome> scriptedOutcomes =
      <AssistantCapabilityOutcome>[];

  /// The exact question every run executed with.
  final List<String> runQuestions = <String>[];

  @override
  bool matches(String question) => isMatch(question);

  @override
  Future<AssistantCapabilityOutcome> run({
    required String question,
    required AssistantContext assistantContext,
  }) async {
    runCount++;
    runQuestions.add(question);
    if (throwOnRun) throw Exception('capability exploded');
    if (scriptedOutcomes.isNotEmpty) return scriptedOutcomes.removeAt(0);
    return outcome;
  }
}
