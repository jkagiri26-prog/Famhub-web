import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_activity_history_capability.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_crop_capability.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_livestock_capability.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/weather/application/assistant/farm_weather_capability.dart';

const AssistantContext _context = AssistantContext(
  route: '/farm',
  moduleId: 'farm_management',
  moduleName: 'Farm Management',
  workspaceName: 'Kibuye Farm',
  workspaceType: 'farmer',
  contextMode: 'farmer',
);

FarmEntity _farm(String id, String name, {double? size}) => FarmEntity(
      id: id,
      farmName: name,
      size: size,
      isActive: true,
      isVerified: true,
    );

FieldEntity _field(String id, String farmId, String name) => FieldEntity(
      id: id,
      farmId: farmId,
      fieldName: name,
      createdAt: DateTime(2026, 1, 1),
    );

LivestockEntity _animal(
  String id, {
  String farmId = 'f1',
  String species = 'Dairy Fresian',
  String? fieldId,
  String? variantId,
  String? breed,
  int count = 1,
  String? healthStatus,
  DateTime? dateOfBirth,
  String? notes,
}) =>
    LivestockEntity(
      id: id,
      farmId: farmId,
      fieldId: fieldId,
      variantId: variantId,
      species: species,
      breed: breed,
      count: count,
      dateOfBirth: dateOfBirth,
      healthStatus: healthStatus,
      notes: notes,
      createdAt: DateTime(2026, 1, 1),
    );

LivestockTaxonomyEntry _tax(
  String variantId,
  String itemName,
  String categoryName,
) =>
    (variantId: variantId, itemName: itemName, categoryName: categoryName);

/// Scripted, recording stand-in for the authorized repository reads.
class _RecordingInputs {
  _RecordingInputs({
    this.farms = const <FarmEntity>[],
    this.animalsByFarm = const <String, List<LivestockEntity>>{},
    this.fieldsByFarm = const <String, List<FieldEntity>>{},
    this.taxonomy = const <LivestockTaxonomyEntry>[],
    this.activitiesByFarm = const <String, List<ActivityModel>>{},
    this.typeNames = const <String, String>{},
    this.productionByFarm = const <String, List<ProductionEntity>>{},
    this.commodities = const <String, String>{},
    this.units = const <String, String>{},
    this.failAnimals = false,
    this.failActivities = false,
  });

  final List<FarmEntity> farms;
  final Map<String, List<LivestockEntity>> animalsByFarm;
  final Map<String, List<FieldEntity>> fieldsByFarm;
  final List<LivestockTaxonomyEntry> taxonomy;
  final Map<String, List<ActivityModel>> activitiesByFarm;
  final Map<String, String> typeNames;
  final Map<String, List<ProductionEntity>> productionByFarm;
  final Map<String, String> commodities;
  final Map<String, String> units;
  final bool failAnimals;
  final bool failActivities;

  final List<String> livestockRequests = <String>[];
  final List<String> activityRequests = <String>[];
  final List<String> productionRequests = <String>[];
  int taxonomyRequests = 0;

  FarmLivestockInputs build() => FarmLivestockInputs(
        farms: farms,
        loadLivestock: (String farmId) async {
          livestockRequests.add(farmId);
          if (failAnimals) {
            throw Exception(
              'Failed to load livestock: column "variant_i" does not exist',
            );
          }
          return animalsByFarm[farmId] ?? const <LivestockEntity>[];
        },
        loadFields: (String farmId) async =>
            fieldsByFarm[farmId] ?? const <FieldEntity>[],
        loadTaxonomy: () async {
          taxonomyRequests += 1;
          return taxonomy;
        },
        loadActivities: (String farmId) async {
          activityRequests.add(farmId);
          if (failActivities) {
            throw Exception('Failed to load activities: permission denied');
          }
          return activitiesByFarm[farmId] ?? const <ActivityModel>[];
        },
        loadActivityTypeNames: () async => typeNames,
        loadProduction: (String farmId) async {
          productionRequests.add(farmId);
          return productionByFarm[farmId] ?? const <ProductionEntity>[];
        },
        loadCommodities: () async => commodities,
        loadUnits: () async => units,
      );
}

FarmLivestockCapability _capability(_RecordingInputs recording) =>
    FarmLivestockCapability(readInputs: recording.build);

Future<AssistantCapabilityOutcome> _run(
  AssistantCapability capability,
  String question,
) =>
    capability.run(question: question, assistantContext: _context);

void _collectKeys(Object? node, Set<String> keys) {
  if (node is Map) {
    node.forEach((Object? key, Object? value) {
      keys.add(key.toString());
      _collectKeys(value, keys);
    });
  } else if (node is List) {
    for (final Object? item in node) {
      _collectKeys(item, keys);
    }
  }
}

List<dynamic> _listOf(Map<String, dynamic> evidence, String key) =>
    evidence[key]! as List<dynamic>;

void main() {
  group('question matching', () {
    test('claims the livestock questions this capability exists for', () {
      const List<String> questions = <String>[
        'Which animals are registered on my farm?',
        'How many cattle do I have recorded?',
        'Tell me about this cow.',
        'Which livestock records are available for this herd?',
        'What breed is my cow?',
        'List my flock.',
        // Care and production facts.
        'Was my cow vaccinated this year?',
        'Has my cow been dewormed?',
        'How much milk have my cattle produced?',
      ];
      for (final String question in questions) {
        expect(
          isLivestockContextQuestion(question),
          isTrue,
          reason: 'should claim: $question',
        );
      }
    });

    test('does not claim advisory, weather, crop, activity or chat questions',
        () {
      const List<String> questions = <String>[
        // Advisory.
        'What should I do about fall armyworm?',
        'How do I treat blight on my tomatoes?',
        'Why is my crop wilting?',
        // Animal noun but no inventory signal — ordinary chat.
        'My goat is lame.',
        'Fish is expensive this week.',
        // Weather.
        "What's the weather on my farm?",
        'Will it rain tomorrow?',
        // Farm/crop inventory.
        'What farms do I have registered?',
        'Which crop is recorded in this field?',
        'What crops have I registered on my farm?',
        'Tell me about the fields on my farm.',
        // Activity history.
        'What activities have been recorded on this farm?',
        'When did I last apply fertilizer to my coffee?',
        'Have I recorded pruning this season?',
      ];
      for (final String question in questions) {
        expect(
          isLivestockContextQuestion(question),
          isFalse,
          reason: 'must not claim: $question',
        );
      }
    });

    test('advisory intent wins even with an animal noun and a signal', () {
      expect(
        isLivestockContextQuestion('I should vaccinate my cows.'),
        isFalse,
      );
      expect(
        isLivestockContextQuestion("What's the best breed for my farm?"),
        isFalse,
      );
      expect(
        isLivestockContextQuestion('Which animals do you recommend?'),
        isFalse,
      );
    });

    test('neighbouring capabilities keep their questions', () {
      expect(isFarmWeatherQuestion('Will it rain tomorrow?'), isTrue);
      expect(isFarmCropContextQuestion('What crops have I registered?'), isTrue);
      expect(
        isFarmActivityHistoryQuestion('What activities have been recorded?'),
        isTrue,
      );
      expect(
        isLivestockContextQuestion('What crops have I registered?'),
        isFalse,
      );
      expect(
        isLivestockContextQuestion('What activities have been recorded?'),
        isFalse,
      );
    });
  });

  group('FarmLivestockCapability.run', () {
    test('several unnamed farms ask instead of choosing, and load nothing',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[
          _farm('f1', 'Alpha Farm'),
          _farm('f2', 'Beta Farm'),
        ],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which animals are registered on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.clarification);
      expect(outcome.text, contains('Which farm do you mean'));
      expect(outcome.text, contains('Alpha Farm'));
      expect(outcome.text, contains('Beta Farm'));
      expect(recording.livestockRequests, isEmpty);
      expect(recording.taxonomyRequests, 0);
    });

    test('no farms on file reports honestly', () async {
      final _RecordingInputs recording = _RecordingInputs();

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which animals are registered on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'livestock_no_farm');
      expect(outcome.text, contains('do not have any farms'));
    });

    test('an inventory question returns redacted group records and counts',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm', size: 2.5)],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal(
              'as1',
              species: 'Dairy Fresian',
              variantId: 'v1',
              breed: 'Fresian',
              count: 12,
              fieldId: 'fd1',
              healthStatus: 'Monitored',
              dateOfBirth: DateTime(2024, 5, 1),
              notes: 'Call Jane on 0711 999 000',
            ),
            _animal(
              'as2',
              species: 'Layers Kenbro',
              variantId: 'v2',
              count: 45,
              fieldId: 'fd2',
            ),
          ],
        },
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[
            _field('fd1', 'f1', 'Main Field'),
            _field('fd2', 'f1', 'North Plot'),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
          _tax('v2', 'layers', 'poultry'),
        ],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which animals are registered on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(recording.livestockRequests, <String>['f1']);
      expect(recording.taxonomyRequests, 1);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(evidence['scope'], 'farm');
      expect(evidence['ordered_by'], contains('created_at'));
      final List<dynamic> rows = _listOf(evidence, 'livestock');
      expect(rows, hasLength(2));
      expect(rows.first, containsPair('species', 'Dairy Fresian'));
      expect(rows.first, containsPair('count', 12));
      expect(rows.first, containsPair('breed', 'Fresian'));
      expect(rows.first, containsPair('field', 'Main Field'));
      expect(rows.first, containsPair('recorded_health_status', 'Monitored'));
      expect(
        rows.first.containsKey('date_of_birth'),
        isTrue,
      );
      // Notes are never shipped.
      expect(jsonEncode(evidence), isNot(contains('0711')));
      final Map<String, int> counts = evidence['counts']! as Map<String, int>;
      expect(counts['groups'], 2);
      expect(counts['head_recorded'], 57);
      final Map<String, dynamic> farm = evidence['farm']! as Map<String, dynamic>;
      expect(farm['name'], 'Kibuye Farm');
      // Nothing was asked that needs the care or production sections.
      expect(recording.activityRequests, isEmpty);
      expect(recording.productionRequests, isEmpty);
      expect(evidence.containsKey('recorded_care_events'), isFalse);
      expect(evidence.containsKey('production_records'), isFalse);
    });

    test('a cattle question resolves through the taxonomy to cattle only',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal('as1', species: 'Dairy Fresian', variantId: 'v1', count: 12),
            _animal('as2', species: 'Layers Kenbro', variantId: 'v2', count: 45),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
          _tax('v2', 'layers', 'poultry'),
        ],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'How many cattle do I have recorded?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(evidence['scope'], 'species');
      expect(evidence['query_species'], 'cattle');
      final List<dynamic> rows = _listOf(evidence, 'livestock');
      expect(rows, hasLength(1));
      expect(rows.single, containsPair('species', 'Dairy Fresian'));
      final Map<String, int> counts = evidence['counts']! as Map<String, int>;
      expect(counts['groups'], 1);
      expect(counts['head_recorded'], 12);
    });

    test('a species question with no matching records says so honestly',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal('as1', species: 'Dairy Fresian', variantId: 'v1', count: 12),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
        ],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'How many goats do I have recorded?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'livestock_no_match');
      expect(outcome.text, contains('"goats"'));
      expect(outcome.text, contains('Dairy Fresian'));
      expect(outcome.text, isNot(contains('goat group')));
    });

    test('a singular animal reference among several groups asks instead of '
        'choosing', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal('as1', species: 'Dairy Fresian', variantId: 'v1', fieldId: 'fd1'),
            _animal('as2', species: 'Dairy Fresian', variantId: 'v1', fieldId: 'fd2'),
          ],
        },
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[
            _field('fd1', 'f1', 'Main Field'),
            _field('fd2', 'f1', 'North Plot'),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
        ],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Tell me about this cow.',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.clarification);
      expect(outcome.text, contains('Which livestock group do you mean'));
      expect(outcome.text, contains('Dairy Fresian (Main Field)'));
      expect(outcome.text, contains('Dairy Fresian (North Plot)'));
      // The example re-matches this capability (noun + signal).
      expect(outcome.text, contains('Tell me about this'));
      // Care and production sections were not requested.
      expect(recording.activityRequests, isEmpty);
      expect(recording.productionRequests, isEmpty);
    });

    test('naming the field resolves the singular reference', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal('as1', species: 'Dairy Fresian', variantId: 'v1', fieldId: 'fd1', count: 6),
            _animal('as2', species: 'Dairy Fresian', variantId: 'v1', fieldId: 'fd2', count: 7),
          ],
        },
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[
            _field('fd1', 'f1', 'Main Field'),
            _field('fd2', 'f1', 'North Plot'),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
        ],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Tell me about this cow in North Plot.',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(evidence['query_field'], 'North Plot');
      final List<dynamic> rows = _listOf(evidence, 'livestock');
      expect(rows, hasLength(1));
      expect(rows.single, containsPair('count', 7));
      expect(
        (evidence['counts']! as Map<String, int>)['head_recorded'],
        7,
      );
    });

    test('a field with no matching records reports honestly', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal('as1', species: 'Dairy Fresian', variantId: 'v1', fieldId: 'fd1'),
          ],
        },
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[
            _field('fd1', 'f1', 'Main Field'),
            _field('fd2', 'f1', 'North Plot'),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
        ],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which animals are in North Plot?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'livestock_no_match');
      expect(outcome.text, contains('North Plot'));
    });

    test('a farm with no livestock records says so honestly', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which animals are registered on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'livestock_no_records');
      expect(outcome.text, contains('Kibuye Farm'));
      expect(outcome.text, contains('not that you keep none'));
      expect(recording.taxonomyRequests, 0);
    });

    test('a failing livestock read becomes a clean honest failure', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        failAnimals: true,
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which animals are registered on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'livestock_unavailable');
      expect(outcome.text, contains('temporarily unavailable'));
      expect(outcome.text, isNot(contains('variant_i')));
      expect(outcome.text, isNot(contains('SELECT')));
      expect(outcome.text, isNot(contains('Exception')));
    });

    test('a failing care-record read becomes a clean honest failure',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal('as1', species: 'Dairy Fresian', variantId: 'v1'),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
        ],
        failActivities: true,
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Has my cow been dewormed?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'livestock_unavailable');
      expect(outcome.text, contains('temporarily unavailable'));
      expect(outcome.text, isNot(contains('permission denied')));
      expect(outcome.text, isNot(contains('Exception')));
    });

    test('care intent reports only recorded care events on these animals',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal('as1', species: 'Dairy Fresian', variantId: 'v1', count: 12),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
        ],
        activitiesByFarm: <String, List<ActivityModel>>{
          'f1': <ActivityModel>[
            ActivityModel(
              id: 'act1',
              activityTypeId: 't1',
              performedAt: DateTime(2026, 3, 1),
              assetId: 'as1',
              notes: 'Private note 0733 111 222',
            ),
            // Not a care type.
            ActivityModel(
              id: 'act2',
              activityTypeId: 't2',
              performedAt: DateTime(2026, 3, 2),
              assetId: 'as1',
            ),
            // Not on a scoped animal (crop asset).
            ActivityModel(
              id: 'act3',
              activityTypeId: 't1',
              performedAt: DateTime(2026, 3, 3),
              assetId: 'other',
            ),
          ],
        },
        typeNames: <String, String>{
          't1': 'Vaccination',
          't2': 'Weighing',
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Was my cow vaccinated this year?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(recording.activityRequests, <String>['f1']);
      final Map<String, dynamic> evidence = outcome.evidence!;
      final List<dynamic> events = _listOf(evidence, 'recorded_care_events');
      expect(events, hasLength(1));
      expect(events.single, containsPair('type', 'Vaccination'));
      expect(events.single, containsPair('animal', 'Dairy Fresian'));
      expect(events.single.containsKey('performed_at'), isTrue);
      expect(evidence['records_caveat'], contains('never that an animal'));
      // Notes and private numbers never ship.
      expect(jsonEncode(evidence), isNot(contains('0733')));
      expect(jsonEncode(evidence), isNot(contains('Private note')));
    });

    test('care intent with no recorded events ships an empty list plus the '
        'caveat instead of an inference', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal('as1', species: 'Dairy Fresian', variantId: 'v1'),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
        ],
        activitiesByFarm: <String, List<ActivityModel>>{
          'f1': <ActivityModel>[
            ActivityModel(
              id: 'act2',
              activityTypeId: 't2',
              performedAt: DateTime(2026, 3, 2),
              assetId: 'as1',
            ),
          ],
        },
        typeNames: <String, String>{'t2': 'Weighing'},
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Has my cow been dewormed?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(_listOf(evidence, 'recorded_care_events'), isEmpty);
      expect(evidence['records_caveat'], contains('never that an animal'));
    });

    test('production intent reports only rows linked to these animals',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal('as1', species: 'Dairy Fresian', variantId: 'v1', count: 12),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
        ],
        productionByFarm: <String, List<ProductionEntity>>{
          'f1': <ProductionEntity>[
            const ProductionEntity(
              id: 'p1',
              assetId: 'as1',
              outputCommodityId: 'cm1',
              unitId: 'u1',
              quantity: 30,
            ),
            const ProductionEntity(
              id: 'p2',
              assetId: 'as1',
              outputCommodityId: 'cm1',
              unitId: 'u1',
              quantity: 25.5,
            ),
            // Not linked to a scoped animal (crop production).
            const ProductionEntity(
              id: 'p3',
              assetId: 'other',
              outputCommodityId: 'cm2',
              quantity: 900,
            ),
          ],
        },
        commodities: <String, String>{'cm1': 'Milk (Dairy)', 'cm2': 'Maize'},
        units: <String, String>{'u1': 'litres'},
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'How much milk have my cattle produced?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(recording.productionRequests, <String>['f1']);
      final Map<String, dynamic> evidence = outcome.evidence!;
      final List<dynamic> rows = _listOf(evidence, 'production_records');
      expect(rows, hasLength(2));
      expect(rows.first, containsPair('commodity', 'Milk (Dairy)'));
      expect(rows.first, containsPair('unit', 'litres'));
      expect(jsonEncode(evidence), isNot(contains('Maize')));
      final List<dynamic> totals = _listOf(evidence, 'production_totals');
      expect(totals.single, containsPair('total_quantity', 55.5));
      expect(evidence['records_caveat'], isNotNull);
    });

    test('a records question pulls both recorded sections', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        animalsByFarm: <String, List<LivestockEntity>>{
          'f1': <LivestockEntity>[
            _animal('as1', species: 'Dairy Fresian', variantId: 'v1'),
          ],
        },
        taxonomy: <LivestockTaxonomyEntry>[
          _tax('v1', 'dairy', 'cattle'),
        ],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which livestock records are available for this herd?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(recording.activityRequests, <String>['f1']);
      expect(recording.productionRequests, <String>['f1']);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(_listOf(evidence, 'recorded_care_events'), isEmpty);
      expect(_listOf(evidence, 'production_records'), isEmpty);
      expect(evidence['records_caveat'], contains('never that an animal'));
    });
  });

  group('evidence construction and redaction', () {
    test('never exposes identifiers, notes or purpose strings', () {
      const String uuidPattern =
          '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
      const FarmEntity farm = FarmEntity(
        id: '3f6a2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        entityId: 'a1b2c3d4-1111-4222-8333-444455556666',
        farmName: 'Kibuye Farm',
        description: 'Call the office on 0722 555 123',
        isActive: true,
        isVerified: true,
      );
      final FieldEntity field = FieldEntity(
        id: '8888aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        farmId: '3f6a2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        fieldName: 'Main Field',
        notes: 'Ask Jane on 0733 111 222',
        createdAt: DateTime(2026, 1, 1),
      );
      final LivestockEntity animal = LivestockEntity(
        id: 'aaaa2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        farmId: '3f6a2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        fieldId: '8888aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        variantId: 'bbbb2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        species: 'Dairy Fresian',
        breed: 'Fresian',
        count: 12,
        healthStatus: 'Monitored',
        purpose: 'Milk & Breeding',
        notes: 'Private note, contact 0711 999 000',
        dateOfBirth: DateTime(2024, 5, 1),
        createdAt: DateTime(2026, 1, 1),
      );

      final Map<String, dynamic> evidence = buildLivestockEvidence(
        scope: 'farm',
        farm: farm,
        livestock: <LivestockEntity>[animal],
        totalGroups: 1,
        headRecorded: 12,
        fieldById: <String, FieldEntity>{field.id: field},
        includeCare: false,
        careEvents: const <ActivityModel>[],
        typeNames: const <String, String>{},
        speciesByAssetId: const <String, String>{},
        includeProduction: false,
        productionRows: const <ProductionEntity>[],
        commodityNames: const <String, String>{},
        unitNames: const <String, String>{},
        productionTruncated: false,
      );
      final String json = jsonEncode(evidence);

      expect(
        RegExp(uuidPattern).hasMatch(json),
        isFalse,
        reason: 'no identifier may reach the model: $json',
      );
      expect(json, isNot(contains('0711')));
      expect(json, isNot(contains('0722')));
      expect(json, isNot(contains('0733')));
      expect(json, isNot(contains('Private note')));

      final Set<String> keys = <String>{};
      _collectKeys(evidence, keys);
      expect(
        keys.intersection(<String>{
          'id',
          'farm_id',
          'asset_id',
          'variant_id',
          'field_id',
          'entity_id',
          'notes',
          'purpose',
          'metadata',
        }),
        isEmpty,
        reason: 'evidence keys were: $keys',
      );

      final Map<String, dynamic> row =
          _listOf(evidence, 'livestock').single as Map<String, dynamic>;
      expect(row['species'], 'Dairy Fresian');
      expect(row['breed'], 'Fresian');
      expect(row['count'], 12);
      expect(row['field'], 'Main Field');
      expect(row['recorded_health_status'], 'Monitored');
      expect(evidence['_note'], contains('never'));
      expect(evidence['capability'], kLivestockCapabilityId);
    });

    test('caps long lists and reports true totals', () {
      final List<LivestockEntity> animals = List<LivestockEntity>.generate(
        25,
        (int i) => _animal('a$i', species: 'Group $i', count: 2),
        growable: false,
      );

      final Map<String, dynamic> evidence = buildLivestockEvidence(
        scope: 'farm',
        farm: _farm('f1', 'Kibuye Farm'),
        livestock: animals,
        totalGroups: 25,
        headRecorded: 50,
        fieldById: const <String, FieldEntity>{},
        includeCare: true,
        careEvents: List<ActivityModel>.generate(
          15,
          (int i) => ActivityModel(
            id: 'c$i',
            activityTypeId: 't1',
            performedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
          ),
          growable: false,
        ),
        typeNames: const <String, String>{'t1': 'Vaccination'},
        speciesByAssetId: const <String, String>{},
        includeProduction: true,
        productionRows: List<ProductionEntity>.generate(
          14,
          (int i) => ProductionEntity(
            id: 'p$i',
            quantity: i.toDouble(),
            outputCommodityId: 'cm$i',
          ),
          growable: false,
        ),
        commodityNames: <String, String>{
          for (int i = 0; i < 14; i++) 'cm$i': 'Commodity $i',
        },
        unitNames: const <String, String>{},
        productionTruncated: true,
      );

      expect(
        _listOf(evidence, 'livestock'),
        hasLength(kMaxLivestockEvidenceEntries),
      );
      expect(evidence['livestock_truncated'], isTrue);
      final Map<String, int> counts = evidence['counts']! as Map<String, int>;
      expect(counts['groups'], 25);
      expect(counts['head_recorded'], 50);

      expect(
        _listOf(evidence, 'recorded_care_events'),
        hasLength(kMaxCareEventEntries),
      );
      expect(
        _listOf(evidence, 'production_records'),
        hasLength(kMaxProductionRowEntries),
      );
      expect(evidence['production_records_truncated'], isTrue);
      expect(evidence['records_caveat'], kLivestockRecordsCaveat);
    });
  });
}
