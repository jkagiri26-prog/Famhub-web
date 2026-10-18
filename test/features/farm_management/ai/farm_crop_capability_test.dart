import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/features/farm_management/application/ai/advisor_capabilities.dart';
import 'package:famhub_app/features/farm_management/application/ai/farm_crop_capability.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
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

CropEntity _crop(
  String id,
  String farmId,
  String name, {
  String? fieldId,
  String? variety,
}) =>
    CropEntity(
      id: id,
      farmId: farmId,
      fieldId: fieldId,
      cropName: name,
      variety: variety,
      plantingDate: DateTime(2026, 3, 1),
      createdAt: DateTime(2026, 3, 1),
    );

/// Scripted, recording stand-in for the authorized repository reads.
/// Records every request; never touches the network or Supabase.
class _RecordingInputs {
  _RecordingInputs({
    this.farms = const <FarmEntity>[],
    this.fieldsByFarm = const <String, List<FieldEntity>>{},
    this.cropsByFarm = const <String, List<CropEntity>>{},
    this.failFields = false,
    this.failCrops = false,
  });

  final List<FarmEntity> farms;
  final Map<String, List<FieldEntity>> fieldsByFarm;
  final Map<String, List<CropEntity>> cropsByFarm;
  final bool failFields;
  final bool failCrops;

  final List<String> fieldRequests = <String>[];
  final List<({String farmId, String? fieldId})> cropRequests =
      <({String farmId, String? fieldId})>[];

  FarmCropInputs build() => FarmCropInputs(
        farms: farms,
        loadFields: (String farmId) async {
          fieldRequests.add(farmId);
          if (failFields) {
            throw Exception(
              'Failed to load fields: column "secret_col" does not exist',
            );
          }
          return fieldsByFarm[farmId] ?? const <FieldEntity>[];
        },
        loadCrops: (String farmId, String? fieldId) async {
          cropRequests.add((farmId: farmId, fieldId: fieldId));
          if (failCrops) {
            throw Exception(
              'Failed to load crops: permission denied for table assets',
            );
          }
          final List<CropEntity> all =
              cropsByFarm[farmId] ?? const <CropEntity>[];
          if (fieldId == null) return all;
          return all
              .where((CropEntity c) => c.fieldId == fieldId)
              .toList(growable: false);
        },
      );
}

FarmCropCapability _capability(_RecordingInputs recording) =>
    FarmCropCapability(readInputs: recording.build);

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
    test('claims the registry questions this capability exists for', () {
      const List<String> questions = <String>[
        'What farms do I have registered?',
        'Which crop is recorded in this field?',
        'What crops have I registered on my farm?',
        'Tell me about the fields on my farm.',
      ];
      for (final String question in questions) {
        expect(
          isFarmCropContextQuestion(question),
          isTrue,
          reason: 'should claim: $question',
        );
      }
    });

    test('does not claim advisory, weather or open-ended questions', () {
      const List<String> questions = <String>[
        'My maize leaves are turning yellow.',
        'What should I do about fall armyworm?',
        'How do I treat blight on my tomatoes?',
        "What's the weather on my farm?",
        'Will it rain tomorrow?',
        'Why is my crop wilting?',
        // No farm/field/crop noun at all.
        'What have I registered?',
        // Entity word but no inventory signal.
        'Please scout the north plot.',
      ];
      for (final String question in questions) {
        expect(
          isFarmCropContextQuestion(question),
          isFalse,
          reason: 'must not claim: $question',
        );
      }
    });

    test('advisory intent wins even when an inventory signal is present',
        () {
      expect(
        isFarmCropContextQuestion('List the crops I should plant'),
        isFalse,
      );
      expect(
        isFarmCropContextQuestion('Tell me about how to treat my crops'),
        isFalse,
      );
      expect(
        isFarmCropContextQuestion('What fields do you recommend?'),
        isFalse,
      );
    });

    test('the weather capability keeps the weather questions', () {
      expect(isFarmWeatherQuestion('Will it rain tomorrow?'), isTrue);
      expect(isFarmCropContextQuestion('Will it rain tomorrow?'), isFalse);
      expect(isFarmWeatherQuestion('What crops have I registered?'), isFalse);
    });
  });

  group('resolveFarmTarget', () {
    test('no farms on file', () {
      final FarmCropFarmResolution resolution = resolveFarmTarget(
        question: 'What crops have I registered?',
        farms: const <FarmEntity>[],
      );
      expect(resolution.status, FarmCropFarmStatus.noFarm);
    });

    test('a single farm needs no naming', () {
      final FarmCropFarmResolution resolution = resolveFarmTarget(
        question: 'What crops have I registered on my farm?',
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
      );
      expect(resolution.status, FarmCropFarmStatus.resolved);
      expect(resolution.farm!.farmName, 'Kibuye Farm');
    });

    test('the farm named in the question wins', () {
      final FarmCropFarmResolution resolution = resolveFarmTarget(
        question: 'What crops are registered at Rwanda Farm?',
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm'),
          _farm('f2', 'Rwanda Farm'),
        ],
      );
      expect(resolution.status, FarmCropFarmStatus.resolved);
      expect(resolution.farm!.id, 'f2');
    });

    test('two matching names ask instead of choosing', () {
      final FarmCropFarmResolution resolution = resolveFarmTarget(
        question: 'What is registered at Alpha Farm and Beta Farm?',
        farms: <FarmEntity>[
          _farm('f1', 'Alpha Farm'),
          _farm('f2', 'Beta Farm'),
        ],
      );
      expect(resolution.status, FarmCropFarmStatus.ambiguous);
      expect(resolution.farmNames, <String>['Alpha Farm', 'Beta Farm']);
    });

    test('several unnamed farms ask instead of taking the first', () {
      final FarmCropFarmResolution resolution = resolveFarmTarget(
        question: 'What crops have I registered on my farm?',
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm'),
          _farm('f2', 'Rwanda Farm'),
          _farm('f3', 'Mbita Farm'),
        ],
      );
      expect(resolution.status, FarmCropFarmStatus.ambiguous);
      expect(resolution.farmNames, hasLength(3));
      expect(resolution.farm, isNull);
    });
  });

  group('resolveFieldTarget', () {
    test('no fields on the farm', () {
      final FarmCropFieldResolution resolution = resolveFieldTarget(
        question: 'Which crop is recorded in this field?',
        fields: const <FieldEntity>[],
      );
      expect(resolution.status, FarmCropFieldStatus.noFields);
    });

    test('a single field needs no naming', () {
      final FarmCropFieldResolution resolution = resolveFieldTarget(
        question: 'Which crop is recorded in this field?',
        fields: <FieldEntity>[_field('fd1', 'f1', 'Main Field')],
      );
      expect(resolution.status, FarmCropFieldStatus.resolved);
      expect(resolution.field!.id, 'fd1');
    });

    test('the field named in the question wins', () {
      final FarmCropFieldResolution resolution = resolveFieldTarget(
        question: 'Which crop is recorded in North Plot?',
        fields: <FieldEntity>[
          _field('fd1', 'f1', 'Main Field'),
          _field('fd2', 'f1', 'North Plot'),
        ],
      );
      expect(resolution.status, FarmCropFieldStatus.resolved);
      expect(resolution.field!.id, 'fd2');
    });

    test('an unnamed field among several asks instead of choosing', () {
      final FarmCropFieldResolution resolution = resolveFieldTarget(
        question: 'Which crop is recorded in this field?',
        fields: <FieldEntity>[
          _field('fd1', 'f1', 'Main Field'),
          _field('fd2', 'f1', 'North Plot'),
        ],
      );
      expect(resolution.status, FarmCropFieldStatus.ambiguous);
      expect(resolution.fieldNames, <String>['Main Field', 'North Plot']);
    });

    test('two matching field names ask instead of choosing', () {
      final FarmCropFieldResolution resolution = resolveFieldTarget(
        question: 'Which crop is recorded in Main Field or North Plot?',
        fields: <FieldEntity>[
          _field('fd1', 'f1', 'Main Field'),
          _field('fd2', 'f1', 'North Plot'),
        ],
      );
      expect(resolution.status, FarmCropFieldStatus.ambiguous);
    });
  });

  group('FarmCropCapability.run', () {
    test('a farm-registry question answers from the farm list alone',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm', size: 2.5),
          _farm('f2', 'Rwanda Farm'),
        ],
      );

      final AssistantCapabilityOutcome outcome =
          await _run(_capability(recording), 'What farms do I have registered?');

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(evidence['scope'], 'farms');
      final List<String> names = _listOf(evidence, 'farms')
          .map((dynamic e) => (e as Map)['name']! as String)
          .toList();
      expect(names, <String>['Kibuye Farm', 'Rwanda Farm']);
      // No field or crop rows are touched for a farm-only question.
      expect(recording.fieldRequests, isEmpty);
      expect(recording.cropRequests, isEmpty);
    });

    test('a crop question on a single farm retrieves its records', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[_field('fd1', 'f1', 'Main Field')],
        },
        cropsByFarm: <String, List<CropEntity>>{
          'f1': <CropEntity>[
            _crop('c1', 'f1', 'Maize', fieldId: 'fd1', variety: 'H614'),
          ],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'What crops have I registered on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(evidence['scope'], 'crops');
      expect(recording.fieldRequests, <String>['f1']);
      expect(recording.cropRequests,
          <({String farmId, String? fieldId})>[(farmId: 'f1', fieldId: null)]);
      final Map<String, dynamic> crop =
          _listOf(evidence, 'crops').single as Map<String, dynamic>;
      expect(crop['name'], 'Maize');
      expect(crop['variety'], 'H614');
      expect(crop['planted_on'], '2026-03-01');
      expect(crop['field'], 'Main Field');
      expect(crop['status'], 'Planted');
    });

    test('several farms with no name ask instead of choosing', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm'),
          _farm('f2', 'Rwanda Farm'),
        ],
        cropsByFarm: <String, List<CropEntity>>{
          'f1': <CropEntity>[_crop('c1', 'f1', 'Maize')],
          'f2': <CropEntity>[_crop('c2', 'f2', 'Beans')],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'What crops have I registered on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.clarification);
      expect(outcome.text, contains('Which farm do you mean'));
      expect(outcome.text, contains('Kibuye Farm'));
      expect(outcome.text, contains('Rwanda Farm'));
      // Nothing is loaded and the gateway is never involved.
      expect(recording.fieldRequests, isEmpty);
      expect(recording.cropRequests, isEmpty);
    });

    test('only the named farm is read and shown', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm'),
          _farm('f2', 'Rwanda Farm'),
        ],
        fieldsByFarm: <String, List<FieldEntity>>{
          'f2': <FieldEntity>[_field('fd2', 'f2', 'River Field')],
        },
        cropsByFarm: <String, List<CropEntity>>{
          'f2': <CropEntity>[_crop('c2', 'f2', 'Beans', fieldId: 'fd2')],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'What crops have I registered at Rwanda Farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(recording.fieldRequests, <String>['f2']);
      final String json = jsonEncode(outcome.evidence);
      expect(json, contains('Rwanda Farm'));
      expect(json, isNot(contains('Kibuye Farm')));
      expect(_listOf(outcome.evidence!, 'farms'), hasLength(1));
    });

    test('a fields question lists the fields and never reads crops',
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
        'Tell me about the fields on my farm.',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(evidence['scope'], 'fields');
      final List<String> names = _listOf(evidence, 'fields')
          .map((dynamic e) => (e as Map)['name']! as String)
          .toList();
      expect(names, <String>['Main Field', 'North Plot']);
      expect(recording.cropRequests, isEmpty);
    });

    test('a singular field reference narrows the crop read to that field',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[_field('fd1', 'f1', 'Main Field')],
        },
        cropsByFarm: <String, List<CropEntity>>{
          'f1': <CropEntity>[_crop('c1', 'f1', 'Maize', fieldId: 'fd1')],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which crop is recorded in this field?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(
        recording.cropRequests,
        <({String farmId, String? fieldId})>[
          (farmId: 'f1', fieldId: 'fd1'),
        ],
      );
      expect(_listOf(outcome.evidence!, 'crops'), hasLength(1));
    });

    test('the field named in the question decides both evidence and load',
        () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[
            _field('fd1', 'f1', 'Main Field'),
            _field('fd2', 'f1', 'North Plot'),
          ],
        },
        cropsByFarm: <String, List<CropEntity>>{
          'f1': <CropEntity>[
            _crop('c1', 'f1', 'Maize', fieldId: 'fd1'),
            _crop('c2', 'f1', 'Beans', fieldId: 'fd2'),
          ],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which crop is recorded in North Plot?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(
        recording.cropRequests,
        <({String farmId, String? fieldId})>[
          (farmId: 'f1', fieldId: 'fd2'),
        ],
      );
      final Map<String, dynamic> evidence = outcome.evidence!;
      expect(_listOf(evidence, 'crops'), hasLength(1));
      expect(_listOf(evidence, 'crops').single, containsPair('name', 'Beans'));
      // Only the resolved field is shipped, not the whole field list.
      expect(_listOf(evidence, 'fields'), hasLength(1));
      expect(_listOf(evidence, 'fields').single,
          containsPair('name', 'North Plot'));
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
        cropsByFarm: <String, List<CropEntity>>{
          'f1': <CropEntity>[_crop('c1', 'f1', 'Maize', fieldId: 'fd1')],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Which crop is recorded in this field?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.clarification);
      expect(outcome.text, contains('Which field do you mean'));
      expect(outcome.text, contains('Main Field'));
      expect(outcome.text, contains('North Plot'));
      expect(recording.cropRequests, isEmpty);
    });

    test('no farms on file reports honestly', () async {
      final _RecordingInputs recording = _RecordingInputs();

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'What crops have I registered on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'farm_crop_no_farm');
      expect(outcome.text, contains('do not have any farms'));
    });

    test('a farm with no fields reports honestly', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Tell me about the fields on my farm.',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'farm_crop_no_fields');
      expect(outcome.text, contains('Kibuye Farm'));
      expect(outcome.text, contains('no fields registered'));
    });

    test('a farm with no crops reports honestly', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[_field('fd1', 'f1', 'Main Field')],
        },
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'What crops have I registered on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'farm_crop_no_crops');
      expect(outcome.text, contains('Kibuye Farm'));
      expect(outcome.text, contains('no crops registered'));
    });

    test('a failing field read becomes a clean honest failure', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        failFields: true,
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'Tell me about the fields on my farm.',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'farm_crop_unavailable');
      expect(outcome.text, contains('temporarily unavailable'));
      // Repository detail (table/column names) never reaches the user
      // or the model.
      expect(outcome.text, isNot(contains('secret_col')));
      expect(outcome.text, isNot(contains('SELECT')));
      expect(outcome.text, isNot(contains('Exception')));
    });

    test('a failing crop read becomes a clean honest failure', () async {
      final _RecordingInputs recording = _RecordingInputs(
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
        fieldsByFarm: <String, List<FieldEntity>>{
          'f1': <FieldEntity>[_field('fd1', 'f1', 'Main Field')],
        },
        failCrops: true,
      );

      final AssistantCapabilityOutcome outcome = await _run(
        _capability(recording),
        'What crops have I registered on my farm?',
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'farm_crop_unavailable');
      expect(outcome.text, isNot(contains('permission denied')));
      expect(outcome.text, isNot(contains('Exception')));
    });
  });

  group('evidence construction and redaction', () {
    test('never exposes identifiers, location ids or free-text notes', () {
      const String uuidPattern =
          '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
      const FarmEntity farm = FarmEntity(
        id: '3f6a2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        entityId: 'a1b2c3d4-1111-4222-8333-444455556666',
        farmName: 'Kibuye Farm',
        description: 'Call the office on 0722 555 123',
        size: 2.5,
        countyId: '5555aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        subCountyId: '6666aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        wardId: '7777aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        isActive: true,
        isVerified: true,
      );
      final FieldEntity field = FieldEntity(
        id: '8888aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        farmId: '3f6a2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        fieldName: 'Main Field',
        notes: 'Ask Jane on 0733 111 222 before spraying',
        unitId: '9999aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        acreage: 1.5,
        createdAt: DateTime(2026, 1, 1),
      );
      final CropEntity crop = CropEntity(
        id: 'aaaa2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        farmId: '3f6a2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        entityId: 'a1b2c3d4-1111-4222-8333-444455556666',
        fieldId: '8888aaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        variantId: 'bbbb2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        cropName: 'Maize',
        variety: 'H614',
        plantingDate: DateTime(2026, 3, 1),
        notes: 'Private note, contact 0711 999 000',
        unit: 'cccc2c1e-8b4d-4e6a-9c2f-1d5b7a9e0c44',
        createdAt: DateTime(2026, 3, 1),
      );

      final Map<String, dynamic> evidence = buildFarmCropEvidence(
        scope: 'crops',
        farms: <FarmEntity>[farm],
        fields: <FieldEntity>[field],
        crops: <CropEntity>[crop],
        fieldNamesById: <String, String>{field.id: field.fieldName},
      );
      final String json = jsonEncode(evidence);

      expect(
        RegExp(uuidPattern).hasMatch(json),
        isFalse,
        reason: 'no identifier may reach the model: $json',
      );
      expect(json, isNot(contains('0722')));
      expect(json, isNot(contains('0733')));
      expect(json, isNot(contains('0711')));

      final Set<String> keys = <String>{};
      _collectKeys(evidence, keys);
      expect(
        keys.intersection(<String>{
          'id',
          'farm_id',
          'entity_id',
          'field_id',
          'variant_id',
          'unit_id',
          'county_id',
          'sub_county_id',
          'ward_id',
          'notes',
          'description',
        }),
        isEmpty,
        reason: 'evidence keys were: $keys',
      );

      // What an answer needs survives: names, variety, dates, status and
      // the field NAME (never its id).
      final Map<String, dynamic> cropEvidence =
          _listOf(evidence, 'crops').single as Map<String, dynamic>;
      expect(cropEvidence['name'], 'Maize');
      expect(cropEvidence['variety'], 'H614');
      expect(cropEvidence['planted_on'], '2026-03-01');
      expect(cropEvidence['field'], 'Main Field');
      expect(evidence['_note'], contains('never'));
      expect(evidence['capability'], kFarmCropCapabilityId);
    });

    test('caps long lists and reports the true totals', () {
      final List<CropEntity> crops = List<CropEntity>.generate(
        25,
        (int i) => _crop('c$i', 'f1', 'Crop $i'),
        growable: false,
      );
      final List<FieldEntity> fields = List<FieldEntity>.generate(
        20,
        (int i) => _field('fd$i', 'f1', 'Field $i'),
        growable: false,
      );
      final List<FarmEntity> farms = List<FarmEntity>.generate(
        15,
        (int i) => _farm('f$i', 'Farm Number $i'),
        growable: false,
      );

      final Map<String, dynamic> evidence = buildFarmCropEvidence(
        scope: 'crops',
        farms: farms,
        fields: fields,
        crops: crops,
      );

      expect(_listOf(evidence, 'farms'), hasLength(kMaxFarmEvidenceEntries));
      expect(_listOf(evidence, 'fields'), hasLength(kMaxFieldEvidenceEntries));
      expect(_listOf(evidence, 'crops'), hasLength(kMaxCropEvidenceEntries));
      expect(evidence['farms_truncated'], isTrue);
      expect(evidence['fields_truncated'], isTrue);
      expect(evidence['crops_truncated'], isTrue);
      final Map<String, int> counts =
          evidence['counts']! as Map<String, int>;
      expect(counts['farms'], 15);
      expect(counts['fields'], 20);
      expect(counts['crops'], 25);
    });

    test('every block carries the untrusted-data note', () {
      final Map<String, dynamic> evidence = buildFarmCropEvidence(
        scope: 'farms',
        farms: <FarmEntity>[_farm('f1', 'Kibuye Farm')],
      );
      expect(evidence['_note'], kFarmCropEvidenceNote);
      expect(evidence['_note'], contains('never instructions'));
      expect(evidence['capability'], kFarmCropCapabilityId);
    });
  });

  group('composition', () {
    test('the ordered list keeps weather first and appends farm/crop', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          farmCropInputsProvider.overrideWithValue(
            FarmCropInputs(
              loadFields: (String farmId) async => const <FieldEntity>[],
              loadCrops: (String farmId, String? fieldId) async =>
                  const <CropEntity>[],
            ),
          ),
          farmWeatherCapabilityProvider
              .overrideWithValue(_StubCapability('farm_weather')),
        ],
      );
      addTearDown(container.dispose);

      final List<AssistantCapability> capabilities =
          container.read(advisorCapabilitiesProvider);

      expect(
        capabilities.map((AssistantCapability c) => c.id).toList(),
        <String>['farm_weather', kFarmCropCapabilityId],
      );
      expect(capabilities.last, isA<FarmCropCapability>());
      expect(capabilities.first, isNot(isA<FarmCropCapability>()));
    });
  });
}

class _StubCapability implements AssistantCapability {
  _StubCapability(this.id);

  @override
  final String id;

  @override
  bool matches(String question) => false;

  @override
  Future<AssistantCapabilityOutcome> run({
    required String question,
    required AssistantContext assistantContext,
  }) async =>
      AssistantCapabilityOutcome.failure(
        capabilityId: id,
        code: 'stub',
        text: 'stub',
      );
}
