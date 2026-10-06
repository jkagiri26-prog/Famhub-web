/// Cache round-trip + refresh behaviour for the Weather feature.
///
/// Replays the two shapes the deployed `app-weather` function produces:
///   1. cache MISS  → freshly normalised payload (`cache.cached == false`)
///   2. cache HIT   → payload replayed from `weather.weather_cache`
///                    (`cache.cached == true`, `current.cached == true`)
///
/// and drives the Riverpod refresh path used by the Weather page's
/// pull-to-refresh (`invalidate` → read `.future` again).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/weather/application/providers/weather_providers.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/domain/weather_exception.dart';
import 'package:famhub_app/features/weather/infrastructure/weather_service.dart';

const String _locationId = '067f88d7-0f4c-43e8-8e7f-d4c46733810e';

Map<String, dynamic> _payload({required bool cached, required bool forecast}) {
  final now = DateTime.utc(2026, 10, 6, 12).toIso8601String();
  return <String, dynamic>{
    'location': <String, dynamic>{
      'locationId': _locationId,
      'latitude': -0.194,
      'longitude': 34.777,
    },
    'current': <String, dynamic>{
      'latitude': -0.194,
      'longitude': 34.777,
      'observedAt': now,
      'fetchedAt': now,
      'temperatureC': 27.5,
      'feelsLikeC': 28.1,
      'condition': <String, dynamic>{'text': 'Sunny', 'code': 'clear'},
      'humidityPercent': 61,
      'precipitationProbabilityPercent': null,
      'rainfallMm': 0.0,
      'windSpeedMps': 3.2,
      'windDirectionDegrees': 72.5,
      'provider': 'weatherapi.com',
      'cached': cached,
      'stale': false,
      'locationId': _locationId,
    },
    'forecast': <String, dynamic>{
      'hourly': <dynamic>[
        if (forecast)
          <String, dynamic>{
            'validAt': now,
            'temperatureC': 28.0,
            'condition': <String, dynamic>{'text': 'Sunny', 'code': 'clear'},
            'humidityPercent': 60,
            'precipitationProbabilityPercent': 10,
            'rainfallMm': 0.0,
            'windSpeedMps': 3.0,
            'windDirectionDegrees': 70.0,
          },
      ],
      'daily': <dynamic>[
        if (forecast)
          <String, dynamic>{
            'date': '2026-10-06',
            'validAt': now,
            'temperatureMinC': 18.0,
            'temperatureMaxC': 30.0,
            'temperatureC': 24.0,
            'condition': <String, dynamic>{'text': 'Sunny', 'code': 'clear'},
            'humidityPercent': 62,
            'precipitationProbabilityPercent': 20,
            'rainfallMm': 0.2,
            'windSpeedMps': 3.1,
            'sunrise': '06:30 AM',
            'sunset': '06:45 PM',
          },
      ],
    },
    'provider': 'weatherapi.com',
    'fetchedAt': now,
    'cache': <String, dynamic>{
      'cached': cached,
      'stale': false,
      'expiresAt': now,
    },
  };
}

void main() {
  group('cache MISS → HIT round-trip through WeatherService', () {
    late HttpServer server;
    late List<int> statusesServed;
    late List<String> bodiesServed;

    const missBody = 0;
    const hitBody = 1;
    const doubleEncodedHitBody = 2;

    int next = missBody;

    setUpAll(() async {
      HttpOverrides.global = null;
      statusesServed = <int>[];
      bodiesServed = <String>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        await utf8.decoder.bind(request).join();
        final mode = next;
        statusesServed.add(mode);
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        final body = _payload(cached: mode != missBody, forecast: true);
        if (mode == doubleEncodedHitBody) {
          // What the client would receive if the cached object were
          // stringified twice (i.e. the body arrives as a JSON string).
          bodiesServed.add(jsonEncode(jsonEncode(body)));
          request.response.write(jsonEncode(jsonEncode(body)));
        } else {
          bodiesServed.add(jsonEncode(body));
          request.response.write(jsonEncode(body));
        }
        await request.response.close();
      });
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    setUp(() {
      next = missBody;
      statusesServed.clear();
      bodiesServed.clear();
    });

    WeatherService service() => WeatherService(
          SupabaseClient('http://127.0.0.1:${server.port}', 'local-test-jwt'),
        );

    const target = WeatherRequestTarget.fromLocationId(_locationId);

    test('first fetch (MISS) and refresh (HIT) both decode', () async {
      final first =
          await service().fetch(target: target, scope: WeatherScope.current);
      expect(first.current?.temperatureC, 27.5);
      expect(first.meta.cached, isFalse);

      next = hitBody;
      final second =
          await service().fetch(target: target, scope: WeatherScope.current);
      expect(second.current?.temperatureC, 27.5);
      expect(second.current?.cached, isTrue);
      expect(second.meta.cached, isTrue);
      expect(second.meta.stale, isFalse);
      expect(second.fetchedAt, isNotNull);
      expect(second.stale, isFalse);
      expect(statusesServed, <int>[missBody, hitBody]);
    });

    test('forecast HIT keeps hourly/daily arrays intact', () async {
      final first =
          await service().fetch(target: target, scope: WeatherScope.forecast);
      expect(first.hourly, hasLength(1));
      expect(first.daily, hasLength(1));

      next = hitBody;
      final second =
          await service().fetch(target: target, scope: WeatherScope.forecast);
      expect(second.hourly, hasLength(1));
      expect(second.daily, hasLength(1));
      expect(second.daily.first.tempMaxC, 30.0);
      expect(second.meta.cached, isTrue);
    });

    test('a double-encoded HIT body is reported as unavailable', () async {
      next = doubleEncodedHitBody;
      await expectLater(
        service().fetch(target: target, scope: WeatherScope.current),
        throwsA(isA<WeatherException>().having(
          (e) => e.message,
          'message',
          WeatherException.unavailable.message,
        )),
      );
    });
  });

  group('refresh path (invalidate → new fetch)', () {
    test('invalidate causes a real second call and returns its result',
        () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          weatherServiceProvider.overrideWithValue(_FakeService(() {
            calls++;
            return calls == 1
                ? _bundle(cached: false)
                : _bundle(cached: true);
          })),
        ],
      );
      addTearDown(container.dispose);

      const target = WeatherRequestTarget.fromLocationId(_locationId);

      final subscription = container.listen(
        weatherCurrentProvider(target),
        (_, __) {},
      );
      addTearDown(subscription.close);

      final first = await container.read(weatherCurrentProvider(target).future);
      expect(first?.meta.cached, isFalse);
      expect(calls, 1);

      // Same call sequence the Weather page pull-to-refresh performs.
      container.invalidate(weatherCurrentProvider);
      container.invalidate(weatherForecastProvider);
      final second =
          await container.read(weatherCurrentProvider(target).future);
      expect(second?.meta.cached, isTrue);
      expect(calls, 2);
    });

    test('a failing refresh surfaces as AsyncError (not stale success)',
        () async {
      var calls = 0;
      final container = ProviderContainer(
        overrides: [
          weatherServiceProvider.overrideWithValue(_FakeService(() {
            calls++;
            if (calls == 1) return _bundle(cached: false);
            throw WeatherException.unavailable;
          })),
        ],
      );
      addTearDown(container.dispose);

      const target = WeatherRequestTarget.fromLocationId(_locationId);

      // The Weather page `ref.watch`es these providers, so a listener is
      // always attached while the pull-to-refresh runs.
      final subscription = container.listen(
        weatherCurrentProvider(target),
        (_, __) {},
      );
      addTearDown(subscription.close);

      await container.read(weatherCurrentProvider(target).future);
      expect(calls, 1);

      container.invalidate(weatherCurrentProvider);
      container.invalidate(weatherForecastProvider);

      await expectLater(
        container.read(weatherCurrentProvider(target).future),
        throwsA(isA<WeatherException>()),
      );

      final state = container.read(weatherCurrentProvider(target));
      expect(state.hasError, isTrue);
      expect(state.error, isA<WeatherException>());
      expect(state.isLoading, isFalse);
      expect(calls, 2);

      // Riverpod's default retry would fire again at +200 ms and keep
      // re-invoking the function for ~44 s. The weather providers opt out.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(calls, 2);
      expect(
        container.read(weatherCurrentProvider(target)).hasError,
        isTrue,
      );
    });
  });
}

WeatherBundle _bundle({required bool cached}) {
  final now = DateTime.utc(2026, 10, 6, 12);
  return WeatherBundle(
    current: CurrentWeather(
      latitude: -0.194,
      longitude: 34.777,
      temperatureC: 27.5,
      condition: 'Sunny',
      fetchedAt: now,
      cached: cached,
    ),
    meta: WeatherMeta(cached: cached, stale: false, fetchedAt: now),
  );
}

class _FakeService extends WeatherService {
  _FakeService(this._next) : super(SupabaseClient('http://localhost', 'x'));

  final WeatherBundle Function() _next;

  @override
  Future<WeatherBundle> fetch({
    required WeatherRequestTarget target,
    required WeatherScope scope,
  }) async => _next();
}
