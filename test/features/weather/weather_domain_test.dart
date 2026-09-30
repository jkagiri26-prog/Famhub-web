import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/domain/weather_exception.dart';

void main() {
  // ══════════════════════════════════════════════════════════
  // REQUEST TARGET
  // ══════════════════════════════════════════════════════════
  group('WeatherRequestTarget', () {
    test('canonical location id builds a usable target', () {
      const target = WeatherRequestTarget.fromLocationId('abc-123');
      expect(target.isUsable, isTrue);
      expect(target.hasLocationId, isTrue);
      expect(target.hasCoordinates, isFalse);
      expect(target.latitude, isNull);
      expect(target.longitude, isNull);
    });

    test('an empty target is not usable', () {
      expect(const WeatherRequestTarget().isUsable, isFalse);
      expect(const WeatherRequestTarget(locationId: '   ').isUsable, isFalse);
      expect(const WeatherRequestTarget(latitude: 1.0).isUsable, isFalse);
      expect(const WeatherRequestTarget(longitude: 1.0).isUsable, isFalse);
    });

    test('coordinates build a usable target', () {
      const target =
          WeatherRequestTarget(latitude: -1.286389, longitude: 36.817223);
      expect(target.isUsable, isTrue);
      expect(target.hasLocationId, isFalse);
      expect(target.hasCoordinates, isTrue);
    });

    test('targets with equal values are equal', () {
      const a = WeatherRequestTarget.fromLocationId('abc');
      const b = WeatherRequestTarget.fromLocationId('abc');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const WeatherRequestTarget.fromLocationId('def')));
    });
  });

  // ══════════════════════════════════════════════════════════
  // ERROR MAPPING
  // ══════════════════════════════════════════════════════════
  group('WeatherException', () {
    test('401 function failure maps to a sign-in message', () {
      final error = WeatherException.fromFunction(
        const FunctionException(
          status: 401,
          details: {
            'error': {'code': 'unauthenticated'},
          },
        ),
      );
      expect(error.message, WeatherException.unauthenticated.message);
      expect(error.code, 'unauthenticated');
      expect(error.status, 401);
    });

    test('unknown failure maps to the generic outage message', () {
      final error = WeatherException.fromFunction(
        const FunctionException(status: 500, details: null),
      );
      expect(error.message, WeatherException.unavailable.message);
      expect(error.status, 500);
    });

    test('error envelope in a success payload is surfaced safely', () {
      final error = WeatherException.fromPayload(const {
        'error': {
          'code': 'invalid_location',
          'message': 'internal helper detail',
        },
      });
      expect(error.code, 'invalid_location');
      expect(error.message, WeatherException.invalidRequest.message);
      expect(error.message.contains('internal helper detail'), isFalse);
    });

    test('messages never leak technical detail', () {
      for (final error in <WeatherException>[
        WeatherException.noLocation,
        WeatherException.unauthenticated,
        WeatherException.invalidRequest,
        WeatherException.unavailable,
      ]) {
        expect(error.message.toLowerCase().contains('weatherapi'), isFalse);
        expect(error.message.toLowerCase().contains('stack'), isFalse);
        expect(error.message, isNotEmpty);
      }
    });
  });

  // ══════════════════════════════════════════════════════════
  // RESPONSE DECODING
  // ══════════════════════════════════════════════════════════
  group('WeatherBundle.fromResponse', () {
    test('decodes a camelCase forecast payload', () {
      final bundle = WeatherBundle.fromResponse(const {
        'scope': 'forecast',
        'current': {
          'temperatureC': 24.6,
          'feelsLikeC': 25.1,
          'condition': 'Partly cloudy',
          'humidityPercent': 61,
          'precipitationProbabilityPercent': 20,
          'rainfallMm': 0.4,
          'windSpeedMps': 3.2,
          'windDirectionDegrees': 72.5,
          'latitude': -1.29,
          'longitude': 36.82,
        },
        'hourly': [
          {'time': '2026-09-30T12:00:00Z', 'temperatureC': 25.0,
           'condition': 'Sunny', 'precipitationProbabilityPercent': 10},
        ],
        'daily': [
          {'date': '2026-09-30', 'tempMaxC': 27.0, 'tempMinC': 17.0,
           'condition': 'Sunny', 'precipitationProbabilityPercent': 30},
        ],
        'cache': {'cached': true, 'stale': false,
                  'fetchedAt': '2026-09-30T10:00:00Z'},
      });

      expect(bundle.current?.temperatureC, 24.6);
      expect(bundle.current?.condition, 'Partly cloudy');
      expect(bundle.current?.humidityPercent, 61);
      expect(bundle.current?.windDirectionDegrees, 72.5);
      expect(bundle.hourly, hasLength(1));
      expect(bundle.hourly.first.temperatureC, 25.0);
      expect(bundle.daily, hasLength(1));
      expect(bundle.daily.first.tempMaxC, 27.0);
      expect(bundle.meta.cached, isTrue);
      expect(bundle.meta.stale, isFalse);
      expect(bundle.meta.fetchedAt, isNotNull);
      expect(bundle.meta.scope, WeatherScope.forecast);
      expect(bundle.stale, isFalse);
    });

    test('decodes the snake_case spelling of the same fields', () {
      final bundle = WeatherBundle.fromResponse(const {
        'scope': 'forecast',
        'current': {
          'temperature_c': 18,
          'condition': 'Light rain',
          'humidity_percent': 88,
          'precipitation_probability_percent': 70,
          'rainfall_mm': '2.5',
          'wind_speed_mps': 5,
        },
        'daily': [
          {'date': '2026-09-30', 'temp_max_c': 21, 'temp_min_c': 14,
           'precipitation_probability_percent': 80},
        ],
      });

      expect(bundle.current?.temperatureC, 18.0);
      expect(bundle.current?.humidityPercent, 88);
      expect(bundle.current?.precipitationProbabilityPercent, 70);
      expect(bundle.current?.rainfallMm, 2.5);
      expect(bundle.current?.windSpeedMps, 5.0);
      expect(bundle.daily.first.tempMinC, 14.0);
      expect(bundle.daily.first.tempMaxC, 21.0);
    });

    test('scope=current without a nested block still yields conditions', () {
      final bundle = WeatherBundle.fromResponse(
        const {
          'scope': 'current',
          'temperatureC': 22.0,
          'condition': 'Clear',
        },
        requestedScope: WeatherScope.current,
      );

      expect(bundle.current, isNotNull);
      expect(bundle.current?.temperatureC, 22.0);
      expect(bundle.hourly, isEmpty);
      expect(bundle.daily, isEmpty);
      expect(bundle.meta.scope, WeatherScope.current);
    });

    test('missing values stay null instead of becoming zeros', () {
      final bundle = WeatherBundle.fromResponse(const {
        'current': {'condition': 'Windy'},
      });

      expect(bundle.current?.temperatureC, isNull);
      expect(bundle.current?.feelsLikeC, isNull);
      expect(bundle.current?.humidityPercent, isNull);
      expect(bundle.current?.rainfallMm, isNull);
      expect(bundle.current?.windSpeedMps, isNull);
      expect(bundle.current?.condition, 'Windy');
      expect(bundle.isEmpty, isFalse);
    });

    test('an error envelope throws a user-safe exception', () {
      expect(
        () => WeatherBundle.fromResponse(const {
          'error': {
            'code': 'location_not_found',
            'message': 'lookup failed for id 123',
          },
        }),
        throwsA(isA<WeatherException>()
            .having((e) => e.code, 'code', 'location_not_found')
            .having((e) => e.message, 'message',
                WeatherException.invalidRequest.message)),
      );
    });

    test('a non-map payload throws the outage exception', () {
      expect(
        () => WeatherBundle.fromResponse('not json'),
        throwsA(same(WeatherException.unavailable)),
      );
    });

    test('empty payload decodes to an empty bundle', () {
      final bundle = WeatherBundle.fromResponse(const {});
      expect(bundle.isEmpty, isTrue);
      expect(bundle.current, isNull);
      expect(bundle.hourly, isEmpty);
      expect(bundle.daily, isEmpty);
    });
  });
}
