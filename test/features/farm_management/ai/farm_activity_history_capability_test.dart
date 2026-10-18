import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_activity_history_capability.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_crop_capability.dart';
import 'package:famhub_app/features/farm_management/domain/entities/asset_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
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

AssetEntity _asset(
  String id,
  String farmId,
  String name, {
  String? fieldId,
}) =>
    AssetEntity(
      id: id,
      farmId: farmId,
      assetType: 'crop',
      fieldId: fieldId,
      assetName: name,
      createdAt: DateTime(2026, 1, 1),
    );

ActivityModel _activity({
  required String id,
  required DateTime performedAt,
  String typeId = 't1',
  String? assetId,
  String? planId,
  String? notes,
}) =>
    ActivityModel(
      id: id,
      activityTypeId: typeId,
      performedAt: performedAt,
      assetId: assetId,
      planId: planId,
      notes: notes,
    );

/// Scripted, recording stand-in for the authorized repository reads.
class _RecordingInputs {
  _RecordingInputs({
    this.farms = const <FarmEntity>[],
    this.activitiesByFarm = const <String, List<ActivityModel>>{},
    this.typeNames = const <String, String>{},
    this.assetsByFarm = const <String, List<AssetEntity>>{},
    this.fieldsByFarm = const <String, List<FieldEntity>>{},
    this.failActivities = false,
  });

  final List<FarmEntity> farms;
  final Map<String, List<ActivityModel>> activitiesByFarm;
  final Map<String, String> typeNames;
  final Map<String, List<AssetEntity>> assetsByFarm;
  final Map<String, List<FieldEntity>> fieldsByFarm;
  final bool failActivities;

  final List<String> activityRequests = <String>[];

  FarmActivityInputs build() => FarmActivityInputs(
        farms: farms,
        loadActivities: (String farmId) async {
          activityRequests.add(farmId);
          if (failActivities) {
            throw Exception(
              'Failed to load activities: column "performed_att" does not exist',
            );
          }
          return activitiesByFarm[farmId] ?? const <ActivityModel>[];
        },
        loadActivityTypeNames: () async => typeNames,
        loadAssets: (String farmId) async =>
            assetsByFarm[farmId] ?? const <AssetEntity>[],
        loadFields: (String farmId) async =>
            fieldsByFarm[farmId] ?? const <FieldEntity>[],
      );
}

FarmActivityCapability _capability(_RecordingInputs recording) =>
    FarmActivityCapability(readInputs: recording.build);

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
    test('claims the activity-history questions this capability exists for',
        () {
      const List<String> questions = <String>[
        'When did I last apply fertilizer to my coffee?',
        'What activities have been recorded on this farm?',
        'Which activities are recorded in North Plot?',
        'Have I recorded pruning this season?',
        // Scheduling questions claim too — they are answered honestly.
        'Is my pruning schedule overdue?',
      ];
      for (final String question in questions) {
        expect(
          isFarmActivityHistoryQuestion(question),
          isTrue,
          reason: 'should claim: $question',
        );
      }
    });

    test('does not claim advisory, weather, farm/crop or ordinary questions',
        () {
      const List<String> questions = <String>[
        // Advisory intent.
        'What should I do about fall armyworm?',
        'How do I treat blight on my tomatoes?',
        'Why is my crop wilting?',
        // Weather.
        "What's the weather on my farm?",
        'Will it rain tomorrow?',
        // Farm/crop registry — must stay with the farm/crop capability.
        'What farms do I have registered?',
        'Which crop is recorded in this field?',
        'What crops have I registered on my farm?',
        'Tell me about the fields on my farm.',
        // Ordinary chat / action without a history signal.
        'My goat is lame.',
        'Please scout the north plot.',
        'Apply fertilizer in March.',
      ];
      for (final String question in questions) {
        expect(
          isFarmActivityHistoryQuestion(question),
          isFalse,
          reason: 'must not claim: $question',
        );
      }
    });

    test('advisory intent wins even with a history, action or schedule word',
        () {
      expect(
        isFarmActivityHistoryQuestion(
          'When did I last apply fertilizer — should I?',
        ),
        isFalse,
      );
      expect(
        isFarmActivityHistoryQuestion('What is the best schedule for spraying?'),
        isFalse,
      );
      expect(
        isFarmActivityHistoryQuestion('How do I record a new activity?'),
        isFalse,
      );
    });

    test('the neighbouring capabilities keep their questions', () {
      expect(isFarmWeatherQuestion('Will it rain tomorrow?'), isTrue);
      expect(isFarmCropContextQuestion('What crops have I registered?'), isTrue);
      expect(isFarmActivityHistoryQuestion('What crops have I registered?'),
          isFalse);
      expect(isFarmActivityHistoryQuestion('Will it rain tomorrow?'), isFalse);
    });
  });

  group('FarmActivityCapability.run', () {
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
        'What activities have been recorded on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.clarification);
      expect(outcome.text, contains('Which farm do you mean'));
      expect(outcome.text, contains('Alpha Farm'));
      expect(outcome.text, contains('Beta Farm'));
      expect(recording.activityRequests, isEmpty);
    });

    test('no farms on file reports honestly', () async {
      final _RecordingInputs recording = _RecordingInputs();

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'What activities have been recorded on this farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'activity_no_farm');
      expect(outcome.text, contains('do not have any farms'));
    });

    test('orders by the actual activity date, newest first', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm', size: 2.5)],
        activitiesByFarm: <String, List<ActivityModel>>{
          'f1': <ActivityModel>[
            _activity(
              id: 'a1',
              performedAt: DateTime(2026, 4, 2, 9),
              assetId: 'as1',
              notes: 'Private note about 0711 999 000',
            ),
            _activity(
              id: 'a3',
              performedAt: DateTime(2026, 1, 10),
              typeId: 't2',
              assetId: 'as2',
            ),
            _activity(
              id: 'a2',
              performedAt: DateTime(2026, 6, 15, 14, 30),
              typeId: 't2',
              planId: 'p1',
            ),
          ],
        },
        typeNames: <String, String>{'t1': 'Pruning', 't2': 'Harvesting'},
        assetsByFarm: <String, List<AssetEntity>>{
          'f1': <AssetEntity>[
            _asset('as1', 'f1', 'Coffee', fieldId: 'fd1'),
            _asset('as2', 'f1', 'Maize', fieldId: 'fd2'),
          ],
        },
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[
            _field('fd1', 'f1', 'Main Field'),
            _field('fd2', 'f1', 'North Plot'),
          ],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'What activities have been recorded on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(recording.activityRequests, <String>['f1']);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(evidence['scope'], 'farm');
      expect(evidence['ordered_by'], contains('performed_at'));
      final List<dynamic> rows = _listOf(evidence, 'activities');
      expect(rows, hasLength(3));
      // Newest first: June > April > January.
      final List<String> dates = rows
          .map((dynamic r) => (r as Map)['performed_at']! as String)
          .toList(growable: false);
      expect(dates.first, startsWith('2026-06-15'));
      expect(dates[1], startsWith('2026-04-02'));
      expect(dates.last, startsWith('2026-01-10'));
      final List<DateTime> parsed = dates.map(DateTime.parse).toList();
      for (int i = 1; i < parsed.length; i++) {
        expect(parsed[i - 1].isAfter(parsed[i]), isTrue,
            reason: 'activities must be strictly newest first');
      }
      // Type names, asset names and field names are resolved for context.
      expect(rows[0]['type'], 'Harvesting');
      expect(rows[1]['type'], 'Pruning');
      expect(rows[1]['asset'], 'Coffee');
      expect(rows[1]['field'], 'Main Field');
      // The plan-linked row has no asset/field label instead of a guess.
      expect(rows[0].containsKey('asset'), isFalse);
      final Map<String, dynamic> farm = evidence['farm']! as Map<String, dynamic>;
      expect(farm['name'], 'Kibuye Farm');
      expect(farm['size'], 2.5);
      final Map<String, int> counts =
          evidence['counts']! as Map<String, int>;
      expect(counts['activities'], 3);
      expect(evidence['activities_truncated'], isNull);
    });

    test('a singular field reference keeps only that field\'s activities',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        activitiesByFarm: <String, List<ActivityModel>>{
          'f1': <ActivityModel>[
            _activity(id: 'a1', performedAt: DateTime(2026, 4, 2), assetId: 'as1'),
            _activity(id: 'a3', performedAt: DateTime(2026, 5, 2), assetId: 'as2'),
            // Plan-linked: not attributable to any field.
            _activity(id: 'a4', performedAt: DateTime(2026, 5, 9), planId: 'p1'),
          ],
        },
        typeNames: <String, String>{'t1': 'Pruning'},
        assetsByFarm: <String, List<AssetEntity>>{
          'f1': <AssetEntity>[
            _asset('as1', 'f1', 'Coffee', fieldId: 'fd1'),
            _asset('as2', 'f1', 'Maize', fieldId: 'fd2'),
          ],
        },
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[
            _field('fd1', 'f1', 'Main Field'),
            _field('fd2', 'f1', 'North Plot'),
          ],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which activities are recorded in North Plot?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(evidence['scope'], 'field');
      expect((evidence['field']! as Map)['name'], 'North Plot');
      final List<dynamic> rows = _listOf(evidence, 'activities');
      expect(rows, hasLength(1));
      expect(rows.single, containsPair('asset', 'Maize'));
      final Map<String, int> counts = evidence['counts']! as Map<String, int>;
      expect(counts['activities'], 1);
    });

    test('a crop named in the question narrows the records to that crop',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        activitiesByFarm: <String, List<ActivityModel>>{
          'f1': <ActivityModel>[
            _activity(id: 'a1', performedAt: DateTime(2026, 4, 2), assetId: 'as1'),
            _activity(id: 'a2', performedAt: DateTime(2026, 4, 5), assetId: 'as2'),
          ],
        },
        typeNames: <String, String>{'t1': 'Pruning'},
        assetsByFarm: <String, List<AssetEntity>>{
          'f1': <AssetEntity>[
            _asset('as1', 'f1', 'Coffee', fieldId: 'fd1'),
            _asset('as2', 'f1', 'Maize', fieldId: 'fd2'),
          ],
        },
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[
            _field('fd1', 'f1', 'Main Field'),
            _field('fd2', 'f1', 'North Plot'),
          ],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'When did I last apply fertilizer to my Coffee?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(evidence['scope'], 'crop');
      final List<dynamic> rows = _listOf(evidence, 'activities');
      expect(rows, hasLength(1));
      expect(rows.single, containsPair('asset', 'Coffee'));
    });

    test('an unnamed singular field among several asks instead of choosing',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[
            _field('fd1', 'f1', 'Main Field'),
            _field('fd2', 'f1', 'North Plot'),
          ],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which activities are recorded in this field?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.clarification);
      expect(outcome.text, contains('Which field do you mean'));
      expect(outcome.text, contains('Main Field'));
      expect(outcome.text, contains('North Plot'));
      expect(recording.activityRequests, isEmpty);
    });

    test('the type-name refinement narrows, and falls back safely', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        activitiesByFarm: <String, List<ActivityModel>>{
          'f1': <ActivityModel>[
            _activity(id: 'a1', performedAt: DateTime(2026, 4, 2), typeId: 't1'),
            _activity(id: 'a2', performedAt: DateTime(2026, 4, 3), typeId: 't2'),
          ],
        },
        typeNames: <String, String>{
          't1': 'Fertilizer Application',
          't2': 'Pruning',
        },
      );
      final FarmActivityCapability capability = _capability(recording);

      final AssistantCapabilityOutcome narrowed = await _run(
        capability,
        'When did I last apply fertilizer to my farm?',
      );
      expect(narrowed.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(_listOf(narrowed.evidence!, 'activities'), hasLength(1));
      expect(
        _listOf(narrowed.evidence!, 'activities').single,
        containsPair('type', 'Fertilizer Application'),
      );
      // Counts still report the true scoped total.
      expect(
        (narrowed.evidence!['counts']! as Map<String, int>)['activities'],
        2,
      );

      // No type word in the question → the full scoped list is kept.
      final AssistantCapabilityOutcome fallback = await _run(
        capability,
        'What activities have been recorded on my farm?',
      );
      expect(fallback.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(_listOf(fallback.evidence!, 'activities'), hasLength(2));
    });

    test('no matching records says so without claiming the work was never done',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'What activities have been recorded on this farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'activity_no_records');
      expect(outcome.text, contains('found no recorded activity records'));
      expect(outcome.text, contains('not that the work was never done'));
    });

    test('a failing activity read becomes a clean honest failure', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        failActivities: true,
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'What activities have been recorded on this farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'activity_unavailable');
      expect(outcome.text, contains('temporarily unavailable'));
      expect(outcome.text, isNot(contains('performed_att')));
      expect(outcome.text, isNot(contains('SELECT')));
      expect(outcome.text, isNot(contains('Exception')));
    });

    test('a season question explains the missing season dates, loading nothing',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Have I recorded pruning this season?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'activity_no_season');
      expect(outcome.text, contains('season dates are kept'));
      // Honest alternative that re-matches this capability.
      expect(outcome.text, contains('When did I last prune?'));
      expect(recording.activityRequests, isEmpty);
    });

    test('a schedule question explains the missing schedule, loading nothing',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Is my pruning schedule overdue?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'activity_no_schedule');
      expect(outcome.text, contains('does not give me a work schedule'));
      expect(outcome.text, contains('What activities have been recorded'));
      expect(recording.activityRequests, isEmpty);
    });
  });

  group('evidence construction and redaction', () {
    test('never exposes identifiers or free-text notes', () {
      const String uuidPattern =
          '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
      const FarmEntity farm = FarmEntity(
        id: '3f6a2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        entityId: 'a1b2c3d4-1111-4222-8333-444455556666',
        farmName: 'Kibuye Farm',
        description: 'Call the office on 0722 555 123',
        countyId: '5555aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        isActive: true,
        isVerified: true,
      );
      final AssetEntity asset = AssetEntity(
        id: 'aaaa2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        farmId: '3f6a2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        assetType: 'crop',
        fieldId: '8888aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        assetName: 'Coffee',
        createdAt: DateTime(2026, 1, 1),
      );
      final FieldEntity field = FieldEntity(
        id: '8888aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        farmId: '3f6a2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        fieldName: 'Main Field',
        notes: 'Ask Jane on 0733 111 222 before spraying',
        createdAt: DateTime(2026, 1, 1),
      );
      final ActivityModel activity = ActivityModel(
        id: 'bbbb2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        activityTypeId: 'cccc2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        performedAt: DateTime(2026, 4, 2, 9),
        assetId: asset.id,
        planId: 'dddd2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        notes: 'Private note, contact 0711 999 000',
        attributeValues: <String, dynamic>{'rate': '200g'},
      );

      final Map<String, dynamic> evidence = buildActivityEvidence(
        scope: 'farm',
        farm: farm,
        activities: <ActivityModel>[activity],
        total: 1,
        typeNames: <String, String>{activity.activityTypeId: 'Pruning'},
        assetById: <String, AssetEntity>{asset.id: asset},
        fieldById: <String, FieldEntity>{field.id: field},
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
          'activity_id',
          'activity_type_id',
          'asset_id',
          'plan_id',
          'farm_id',
          'entity_id',
          'field_id',
          'notes',
          'description',
          'attribute_values',
        }),
        isEmpty,
        reason: 'evidence keys were: $keys',
      );

      // What an answer needs survives: type name, date, asset, field NAME.
      final Map<String, dynamic> row =
          _listOf(evidence, 'activities').single as Map<String, dynamic>;
      expect(row['type'], 'Pruning');
      expect(row['performed_at'], startsWith('2026-04-02'));
      expect(row['asset'], 'Coffee');
      expect(row['field'], 'Main Field');
      expect(evidence['_note'], contains('never'));
      expect(evidence['capability'], kFarmActivityCapabilityId);
      expect(evidence['ordered_by'], contains('performed_at'));
    });

    test('caps long lists and reports the true totals', () {
      final List<ActivityModel> activities = List<ActivityModel>.generate(
        25,
        (int i) => _activity(
          id: 'a$i',
          performedAt: DateTime(2026, 1, 1).add(Duration(days: i)),
        ),
        growable: false,
      );

      final Map<String, dynamic> evidence = buildActivityEvidence(
        scope: 'farm',
        farm: _farm('f1', 'Kibuye Farm'),
        activities: activities,
        total: 25,
        typeNames: const <String, String>{},
        assetById: const <String, AssetEntity>{},
        fieldById: const <String, FieldEntity>{},
      );

      expect(
        _listOf(evidence, 'activities'),
        hasLength(kMaxActivityEvidenceEntries),
      );
      expect(evidence['activities_truncated'], isTrue);
      final Map<String, int> counts = evidence['counts']! as Map<String, int>;
      expect(counts['activities'], 25);
    });
  });
}
