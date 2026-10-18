import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_capability.dart';
import 'package:famhub_app/core/shell/application/assistant/assistant_context.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/weather/application/assistant/farm_weather_capability.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/domain/weather_exception.dart';
import 'package:famhub_app/features/weather/infrastructure/weather_service.dart';

const AssistantContext _context = AssistantContext(
  route: '/farm',
  moduleId: 'farm_management',
  moduleName: 'Farm Management',
  workspaceName: 'Kibuye Farm',
  workspaceType: 'farmer',
  contextMode: 'farmer',
);

FarmEntity _farm(
  String id,
  String name, {
  String? wardId,
  String? subCountyId,
  String? countyId,
}) {
  return FarmEntity(
    id: id,
    farmName: name,
    wardId: wardId,
    subCountyId: subCountyId,
    countyId: countyId,
    isActive: true,
    isVerified: true,
  );
}

/// Stand-in for the deployed `app-weather` client. Records what it was
/// asked for; never touches the network.
class _FakeWeatherService implements WeatherService {
  _FakeWeatherService({this.bundle, this.error});

  WeatherBundle? bundle;
  Object? error;

  final List<WeatherRequestTarget> targets = <WeatherRequestTarget>[];
  final List<WeatherScope> scopes = <WeatherScope>[];

  @override
  Future<WeatherBundle> fetch({
    required WeatherRequestTarget target,
    required WeatherScope scope,
  }) async {
    targets.add(target);
    scopes.add(scope);
    if (error != null) throw error!;
    return bundle ?? const WeatherBundle();
  }
}

final WeatherBundle _currentBundle = WeatherBundle(
  current: CurrentWeather(
    temperatureC: 24.5,
    feelsLikeC: 25.0,
    condition: 'Partly cloudy',
    humidityPercent: 68,
    precipitationProbabilityPercent: 30,
    rainfallMm: 0.2,
    windSpeedMps: 3.4,
    // Deliberate: coordinates arrive from the backend and must never be
    // forwarded to the model.
    latitude: -1.2921,
    longitude: 36.8219,
    observedAt: DateTime(2026, 10, 18, 9, 0),
  ),
  meta: WeatherMeta(
    fetchedAt: DateTime(2026, 10, 18, 9, 5),
    scope: WeatherScope.current,
    cached: true,
    stale: false,
  ),
);

final WeatherBundle _forecastBundle = WeatherBundle(
  hourly: <HourlyForecast>[
    HourlyForecast(
      time: DateTime(2026, 10, 18, 12),
      temperatureC: 26,
      condition: 'Sunny',
    ),
  ],
  daily: <DailyForecast>[
    DailyForecast(
      date: DateTime(2026, 10, 19),
      condition: 'Light rain',
      tempMaxC: 27,
      tempMinC: 16,
      rainfallMm: 4.1,
    ),
    DailyForecast(date: DateTime(2026, 10, 20), condition: 'Cloudy'),
  ],
  meta: WeatherMeta(
    fetchedAt: DateTime(2026, 10, 18, 9, 5),
    scope: WeatherScope.forecast,
  ),
);

FarmWeatherCapability _capability(
  _FakeWeatherService service,
  FarmWeatherInputs inputs,
) {
  return FarmWeatherCapability(
    weatherService: service,
    readInputs: () => inputs,
  );
}

void main() {
  group('question matching', () {
    test('claims clear weather questions', () {
      expect(isFarmWeatherQuestion("What's the weather on my farm?"), isTrue);
      expect(isFarmWeatherQuestion('Will it rain on my coffee farm today?'), isTrue);
      expect(isFarmWeatherQuestion('Give me the forecast for the next few days.'), isTrue);
      expect(isFarmWeatherQuestion('Is it going to be humid this week?'), isTrue);
    });

    test('does not claim ordinary advisory questions', () {
      expect(isFarmWeatherQuestion('My maize leaves are yellow.'), isFalse);
      expect(isFarmWeatherQuestion('My goat is not eating.'), isFalse);
      expect(isFarmWeatherQuestion('What price does maize fetch at the market?'), isFalse);
    });

    test('scope defaults to current conditions', () {
      expect(
        farmWeatherScopeFor("What's the weather on my farm?"),
        WeatherScope.current,
      );
      expect(
        farmWeatherScopeFor('Will it rain today?'),
        WeatherScope.current,
      );
    });

    test('scope becomes forecast when a coming period is named', () {
      expect(
        farmWeatherScopeFor('Give me the forecast for the next few days.'),
        WeatherScope.forecast,
      );
      expect(
        farmWeatherScopeFor('Will it rain tomorrow?'),
        WeatherScope.forecast,
      );
      expect(
        farmWeatherScopeFor("What's the outlook for next week?"),
        WeatherScope.forecast,
      );
    });
  });

  group('resolveFarmWeatherTarget', () {
    test('uses the only farm the user has', () {
      final FarmWeatherResolution resolution = resolveFarmWeatherTarget(
        question: "What's the weather on my farm?",
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm', wardId: 'w1'),
        ],
      );

      expect(resolution.status, FarmWeatherTargetStatus.resolved);
      expect(resolution.target!.locationId, 'w1');
      expect(resolution.label, 'Kibuye Farm');
    });

    test('uses the farm the farmer named in their own words', () {
      final FarmWeatherResolution resolution = resolveFarmWeatherTarget(
        question: 'Will it rain on my coffee farm today?',
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm', wardId: 'w1'),
          _farm('f2', 'Coffee Farm', wardId: 'w2'),
          _farm('f3', 'Ngong Hills', countyId: 'c3'),
        ],
      );

      expect(resolution.status, FarmWeatherTargetStatus.resolved);
      expect(resolution.target!.locationId, 'w2');
      expect(resolution.label, 'Coffee Farm');
    });

    test('asks which farm when several exist and none was named', () {
      final FarmWeatherResolution resolution = resolveFarmWeatherTarget(
        question: "What's the weather on my farm?",
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm', wardId: 'w1'),
          _farm('f2', 'Coffee Farm', wardId: 'w2'),
        ],
      );

      expect(resolution.status, FarmWeatherTargetStatus.ambiguous);
      expect(resolution.farmNames, containsAll(<String>['Kibuye Farm', 'Coffee Farm']));
      expect(resolution.target, isNull);
    });

    test('does not treat an auto-selected hierarchy farm as intent', () {
      // resolveFarmWeatherTarget is given the visible farm list only. The
      // hierarchy's "selected" farm is bootstrap auto-selection, so it must
      // never be consulted here — several visible farms always means ask.
      final FarmWeatherResolution resolution = resolveFarmWeatherTarget(
        question: 'What is the weather?',
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm', wardId: 'w1'),
          _farm('f2', 'Coffee Farm', wardId: 'w2'),
        ],
      );

      expect(resolution.status, FarmWeatherTargetStatus.ambiguous);
    });

    test('never selects an unauthorized farm that was only named in text', () {
      // "Secret Farm" is not in the authorized list. The resolver must not
      // invent a target for it, and must not fall back to another farm.
      final FarmWeatherResolution resolution = resolveFarmWeatherTarget(
        question: "What's the weather at Secret Farm?",
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm', wardId: 'w1'),
          _farm('f2', 'Coffee Farm', wardId: 'w2'),
        ],
      );

      expect(resolution.status, FarmWeatherTargetStatus.ambiguous);
      expect(resolution.target, isNull);
      expect(resolution.farmNames, isNot(contains('Secret Farm')));
    });

    test('says so when there is no farm at all', () {
      final FarmWeatherResolution resolution = resolveFarmWeatherTarget(
        question: "What's the weather on my farm?",
        farms: const <FarmEntity>[],
      );

      expect(resolution.status, FarmWeatherTargetStatus.noFarm);
    });

    test('reports a farm with no registered location instead of guessing', () {
      final FarmWeatherResolution resolution = resolveFarmWeatherTarget(
        question: "What's the weather?",
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm'),
        ],
      );

      expect(resolution.status, FarmWeatherTargetStatus.noLocation);
      expect(resolution.label, 'Kibuye Farm');
      expect(resolution.target, isNull);
    });

    test('prefers the most granular registered location', () {
      final FarmWeatherResolution ward = resolveFarmWeatherTarget(
        question: 'weather',
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm', wardId: 'w1', subCountyId: 's1', countyId: 'c1'),
        ],
      );
      expect(ward.target!.locationId, 'w1');

      final FarmWeatherResolution county = resolveFarmWeatherTarget(
        question: 'weather',
        farms: <FarmEntity>[
          _farm('f1', 'Kibuye Farm', countyId: 'c1'),
        ],
      );
      expect(county.target!.locationId, 'c1');
    });
  });

  group('FarmWeatherCapability.run', () {
    test('fetches current conditions for the resolved farm', () async {
      final _FakeWeatherService service = _FakeWeatherService(
        bundle: _currentBundle,
      );
      final FarmWeatherCapability capability = _capability(
        service,
        const FarmWeatherInputs(farms: <FarmEntity>[
          FarmEntity(
            id: 'f1',
            farmName: 'Kibuye Farm',
            wardId: 'w1',
            isActive: true,
            isVerified: true,
          ),
        ]),
      );

      final outcome = await capability.run(
        question: "What's the weather on my farm?",
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(service.scopes, <WeatherScope>[WeatherScope.current]);
      expect(service.targets.single.locationId, 'w1');
    });

    test('fetches the forecast when a coming period is asked for', () async {
      final _FakeWeatherService service = _FakeWeatherService(
        bundle: _forecastBundle,
      );
      final FarmWeatherCapability capability = _capability(
        service,
        const FarmWeatherInputs(farms: <FarmEntity>[
          FarmEntity(
            id: 'f1',
            farmName: 'Kibuye Farm',
            wardId: 'w1',
            isActive: true,
            isVerified: true,
          ),
        ]),
      );

      final outcome = await capability.run(
        question: 'Give me the forecast for the next few days.',
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(service.scopes, <WeatherScope>[WeatherScope.forecast]);
      expect(outcome.evidence!['scope'], 'forecast');
    });

    test('asks a clarification instead of picking a farm', () async {
      final _FakeWeatherService service = _FakeWeatherService();
      final FarmWeatherCapability capability = _capability(
        service,
        const FarmWeatherInputs(farms: <FarmEntity>[
          FarmEntity(
            id: 'f1',
            farmName: 'Kibuye Farm',
            wardId: 'w1',
            isActive: true,
            isVerified: true,
          ),
          FarmEntity(
            id: 'f2',
            farmName: 'Coffee Farm',
            wardId: 'w2',
            isActive: true,
            isVerified: true,
          ),
        ]),
      );

      final outcome = await capability.run(
        question: "What's the weather on my farm?",
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.clarification);
      expect(outcome.text, contains('Which farm'));
      // Nothing was fetched and no farm was chosen.
      expect(service.targets, isEmpty);
    });

    test('reports a missing farm honestly', () async {
      final _FakeWeatherService service = _FakeWeatherService();
      final FarmWeatherCapability capability = _capability(
        service,
        const FarmWeatherInputs(),
      );

      final outcome = await capability.run(
        question: "What's the weather on my farm?",
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'weather_no_farm');
      expect(service.targets, isEmpty);
    });

    test('reports a missing registered location honestly', () async {
      final _FakeWeatherService service = _FakeWeatherService();
      final FarmWeatherCapability capability = _capability(
        service,
        const FarmWeatherInputs(farms: <FarmEntity>[
          FarmEntity(
            id: 'f1',
            farmName: 'Kibuye Farm',
            isActive: true,
            isVerified: true,
          ),
        ]),
      );

      final outcome = await capability.run(
        question: "What's the weather on my farm?",
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'weather_no_location');
      expect(outcome.text, contains('Kibuye Farm'));
      expect(service.targets, isEmpty);
    });

    test('reports a backend refusal without inventing a reading', () async {
      final _FakeWeatherService service = _FakeWeatherService(
        error: WeatherException.unauthenticated,
      );
      final FarmWeatherCapability capability = _capability(
        service,
        const FarmWeatherInputs(farms: <FarmEntity>[
          FarmEntity(
            id: 'f1',
            farmName: 'Kibuye Farm',
            wardId: 'w1',
            isActive: true,
            isVerified: true,
          ),
        ]),
      );

      final outcome = await capability.run(
        question: "What's the weather on my farm?",
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.text, WeatherException.unauthenticated.message);
      expect(outcome.evidence, isNull);
    });

    test('reports an outage without inventing a reading', () async {
      final _FakeWeatherService service = _FakeWeatherService(
        error: WeatherException.unavailable,
      );
      final FarmWeatherCapability capability = _capability(
        service,
        const FarmWeatherInputs(farms: <FarmEntity>[
          FarmEntity(
            id: 'f1',
            farmName: 'Kibuye Farm',
            wardId: 'w1',
            isActive: true,
            isVerified: true,
          ),
        ]),
      );

      final outcome = await capability.run(
        question: "What's the weather on my farm?",
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'weather_unavailable');
      expect(outcome.evidence, isNull);
    });

    test('reports an empty payload honestly', () async {
      final _FakeWeatherService service = _FakeWeatherService(
        bundle: const WeatherBundle(),
      );
      final FarmWeatherCapability capability = _capability(
        service,
        const FarmWeatherInputs(farms: <FarmEntity>[
          FarmEntity(
            id: 'f1',
            farmName: 'Kibuye Farm',
            wardId: 'w1',
            isActive: true,
            isVerified: true,
          ),
        ]),
      );

      final outcome = await capability.run(
        question: "What's the weather on my farm?",
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.failure);
      expect(outcome.code, 'weather_empty');
    });

    test('never reuses the previous farm after a switch', () async {
      final _FakeWeatherService service = _FakeWeatherService(
        bundle: _currentBundle,
      );
      FarmWeatherInputs inputs = const FarmWeatherInputs(
        farms: <FarmEntity>[
          FarmEntity(
            id: 'f1',
            farmName: 'Kibuye Farm',
            wardId: 'w1',
            isActive: true,
            isVerified: true,
          ),
        ],
      );
      final FarmWeatherCapability capability = FarmWeatherCapability(
        weatherService: service,
        readInputs: () => inputs,
      );

      await capability.run(
        question: "What's the weather on my farm?",
        assistantContext: _context,
      );

      // Workspace / farm switch: the authorized list changes.
      inputs = const FarmWeatherInputs(
        farms: <FarmEntity>[
          FarmEntity(
            id: 'f2',
            farmName: 'Ngong Hills',
            wardId: 'w9',
            isActive: true,
            isVerified: true,
          ),
        ],
      );

      final outcome = await capability.run(
        question: "What's the weather on my farm?",
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(outcome.evidence!['location_label'], 'Ngong Hills');
      // The new run used the new location — nothing from the first farm.
      expect(service.targets.map((t) => t.locationId), <String>['w1', 'w9']);
    });

    test('never fetches a farm that left the authorized list', () async {
      final _FakeWeatherService service = _FakeWeatherService(
        bundle: _currentBundle,
      );
      FarmWeatherInputs inputs = const FarmWeatherInputs(
        farms: <FarmEntity>[
          FarmEntity(
            id: 'f1',
            farmName: 'Kibuye Farm',
            wardId: 'w1',
            isActive: true,
            isVerified: true,
          ),
          FarmEntity(
            id: 'f2',
            farmName: 'Coffee Farm',
            wardId: 'w2',
            isActive: true,
            isVerified: true,
          ),
        ],
      );
      final FarmWeatherCapability capability = FarmWeatherCapability(
        weatherService: service,
        readInputs: () => inputs,
      );

      // "Coffee Farm" is visible here, so it resolves once.
      await capability.run(
        question: "What's the weather at Coffee Farm?",
        assistantContext: _context,
      );
      expect(service.targets.single.locationId, 'w2');

      // Access is revoked between turns. The revoked farm must never be
      // requested again, and the evidence must name whichever farm is
      // actually used rather than pretending to answer for the other one.
      inputs = const FarmWeatherInputs(
        farms: <FarmEntity>[
          FarmEntity(
            id: 'f1',
            farmName: 'Kibuye Farm',
            wardId: 'w1',
            isActive: true,
            isVerified: true,
          ),
        ],
      );

      final outcome = await capability.run(
        question: "What's the weather on my farm?",
        assistantContext: _context,
      );

      expect(outcome.kind, AssistantCapabilityOutcomeKind.evidence);
      expect(outcome.evidence!['location_label'], 'Kibuye Farm');
      expect(
        service.targets.map((t) => t.locationId),
        <String>['w2', 'w1'],
      );
      // The revoked farm is not requested again after the switch.
      expect(
        service.targets.map((t) => t.locationId).skip(1),
        isNot(contains('w2')),
      );
    });
  });

  group('evidence', () {
    test('carries the observation the model needs', () async {
      final Map<String, dynamic> evidence = buildWeatherEvidence(
        bundle: _currentBundle,
        scope: WeatherScope.current,
        locationLabel: 'Kibuye Farm',
        locationSource: 'farm',
      );

      expect(evidence['capability'], kFarmWeatherCapabilityId);
      expect(evidence['scope'], 'current');
      expect(evidence['location_label'], 'Kibuye Farm');
      expect(evidence['location_source'], 'farm');
      expect(evidence['data_quality'], 'ok');
      expect(evidence['retrieved_at'], isNotNull);

      final Map<String, dynamic> observation =
          evidence['observation'] as Map<String, dynamic>;
      expect(observation['temperature_c'], 24.5);
      expect(observation['condition'], 'Partly cloudy');
      expect(observation['humidity_percent'], 68);
      expect(observation['rainfall_mm'], 0.2);
      expect(observation['precipitation_probability_percent'], 30);
      expect(observation['observed_at'], isNotNull);
    });

    test('labels retrieved data as evidence, never as instructions', () {
      final Map<String, dynamic> evidence = buildWeatherEvidence(
        bundle: _currentBundle,
        scope: WeatherScope.current,
        locationLabel: 'Kibuye Farm',
        locationSource: 'farm',
      );

      expect(evidence['_note'], kWeatherEvidenceNote);
      expect(kWeatherEvidenceNote, contains('never'));
      expect(kWeatherEvidenceNote, contains('instructions'));
    });

    test('never ships coordinates, provider identity or condition codes', () {
      final Map<String, dynamic> evidence = buildWeatherEvidence(
        bundle: _currentBundle,
        scope: WeatherScope.current,
        locationLabel: 'Kibuye Farm',
        locationSource: 'farm',
      );

      final String flat = evidence.toString().toLowerCase();
      expect(flat, isNot(contains('latitude')));
      expect(flat, isNot(contains('longitude')));
      expect(flat, isNot(contains('-1.2921')));
      expect(flat, isNot(contains('36.8219')));
      expect(flat, isNot(contains('provider')));
      expect(flat, isNot(contains('condition_code')));
    });

    test('contains no credential-shaped keys', () {
      final Map<String, dynamic> evidence = buildWeatherEvidence(
        bundle: _forecastBundle,
        scope: WeatherScope.forecast,
        locationLabel: 'Kibuye Farm',
        locationSource: 'farm',
      );

      final List<String> keys = <String>[];
      void walk(Object? value) {
        if (value is Map) {
          value.forEach((Object? key, Object? child) {
            keys.add(key.toString().toLowerCase());
            walk(child);
          });
        } else if (value is List) {
          for (final Object? child in value) {
            walk(child);
          }
        }
      }

      walk(evidence);

      for (final String secret in <String>[
        'api_key',
        'apikey',
        'token',
        'secret',
        'password',
        'authorization',
        'bearer',
        'service_role',
        'latitude',
        'longitude',
        'lat',
        'lon',
      ]) {
        expect(keys, isNot(contains(secret)));
      }
    });

    test('marks stale data so it is never presented as current fact', () {
      const WeatherBundle stale = WeatherBundle(
        current: CurrentWeather(temperatureC: 20, stale: true),
        meta: WeatherMeta(stale: true),
      );

      final Map<String, dynamic> evidence = buildWeatherEvidence(
        bundle: stale,
        scope: WeatherScope.current,
        locationLabel: 'Kibuye Farm',
        locationSource: 'farm',
      );

      expect(evidence['data_quality'], 'stale');
    });

    test('caps forecast evidence and keeps it JSON-safe', () {
      final List<HourlyForecast> hourly = List<HourlyForecast>.generate(
        48,
        (int i) => HourlyForecast(time: DateTime(2026, 10, 18, i), temperatureC: i.toDouble()),
      );
      final List<DailyForecast> daily = List<DailyForecast>.generate(
        14,
        (int i) => DailyForecast(date: DateTime(2026, 10, 19).add(Duration(days: i))),
      );

      final Map<String, dynamic> evidence = buildWeatherEvidence(
        bundle: WeatherBundle(hourly: hourly, daily: daily),
        scope: WeatherScope.forecast,
        locationLabel: 'Kibuye Farm',
        locationSource: 'farm',
      );

      final Map<String, dynamic> forecast =
          evidence['forecast'] as Map<String, dynamic>;
      expect(
        (forecast['hourly'] as List<dynamic>).length,
        kMaxHourlyEvidenceEntries,
      );
      expect(
        (forecast['daily'] as List<dynamic>).length,
        kMaxDailyEvidenceEntries,
      );
      expect(
        (forecast['daily'] as List<dynamic>).first['date'],
        '2026-10-19',
      );
    });

    test('reports an empty payload as empty rather than ok', () {
      final Map<String, dynamic> evidence = buildWeatherEvidence(
        bundle: const WeatherBundle(),
        scope: WeatherScope.current,
        locationLabel: 'Kibuye Farm',
        locationSource: 'farm',
      );

      expect(evidence['data_quality'], 'empty');
      expect(evidence.containsKey('observation'), isFalse);
      expect(evidence.containsKey('forecast'), isFalse);
    });
  });
}
