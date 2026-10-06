/// ============================================================
/// WEATHER MODELS (PROVIDER-INDEPENDENT, NORMALIZED)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/weather/domain/models/ = weather domain layer
///
/// ✅ Responsibilities:
///   - Typed, immutable views of the NORMALIZED `app-weather` response
///   - Tolerant decoding of null/missing values (never fabricate zeros)
///
/// ❌ Does NOT:
///   - Model WeatherAPI.com payloads
///   - Contain provider API keys or provider-specific request logic
///   - Perform network access
///
/// 📌 DECODING NOTE:
///   The deployed `app-weather` contract was not reachable without an
///   authenticated session during implementation, so decoding accepts the
///   documented normalized field names in either camelCase or snake_case
///   spelling. It deliberately does NOT interpret provider-specific
///   structures or numeric condition codes.
/// ============================================================
library;

import 'dart:convert';

import 'package:famhub_app/features/weather/domain/weather_exception.dart';

// ════════════════════════════════════════════════════════════
// REQUEST TARGET + SCOPE
// ════════════════════════════════════════════════════════════

/// Weather payload the backend should resolve.
enum WeatherScope {
  /// Current conditions only (small payload — dashboard cards).
  current,

  /// Hourly + daily forecast (larger payload — weather page).
  forecast,
}

/// Location a weather request should be resolved against.
///
/// Exactly one form is used per request:
///   canonical location → `{"location_id": "<uuid>"}`
///   explicit position  → `{"latitude": …, "longitude": …}`
class WeatherRequestTarget {
  final String? locationId;
  final double? latitude;
  final double? longitude;

  const WeatherRequestTarget({
    this.locationId,
    this.latitude,
    this.longitude,
  });

  const WeatherRequestTarget.fromLocationId(String this.locationId)
      : latitude = null,
        longitude = null;

  bool get hasLocationId => locationId != null && locationId!.trim().isNotEmpty;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// `true` when a request can actually be built from this target.
  bool get isUsable => hasLocationId || hasCoordinates;

  @override
  bool operator ==(Object other) =>
      other is WeatherRequestTarget &&
      other.locationId == locationId &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(locationId, latitude, longitude);
}

// ════════════════════════════════════════════════════════════
// CURRENT CONDITIONS
// ════════════════════════════════════════════════════════════

class CurrentWeather {
  final double? latitude;
  final double? longitude;
  final DateTime? observedAt;
  final DateTime? fetchedAt;
  final double? temperatureC;
  final double? feelsLikeC;
  final String? condition;
  final String? conditionCode;
  final int? humidityPercent;
  final int? precipitationProbabilityPercent;
  final double? rainfallMm;
  final double? windSpeedMps;
  final double? windDirectionDegrees;
  final String? provider;
  final bool cached;
  final bool stale;

  const CurrentWeather({
    this.latitude,
    this.longitude,
    this.observedAt,
    this.fetchedAt,
    this.temperatureC,
    this.feelsLikeC,
    this.condition,
    this.conditionCode,
    this.humidityPercent,
    this.precipitationProbabilityPercent,
    this.rainfallMm,
    this.windSpeedMps,
    this.windDirectionDegrees,
    this.provider,
    this.cached = false,
    this.stale = false,
  });

  factory CurrentWeather.fromMap(Map<String, dynamic> map, {Map<String, dynamic>? meta}) {
    final source = _Json.merge(meta, map);
    return CurrentWeather(
      latitude: _Json.number(source, ['latitude', 'lat']),
      longitude: _Json.number(source, ['longitude', 'lon', 'lng']),
      observedAt: _Json.time(
        source,
        ['observedAt', 'observed_at', 'observationTime', 'observation_time',
         'lastUpdated', 'last_updated', 'time'],
      ),
      fetchedAt: _Json.time(
        source,
        ['fetchedAt', 'fetched_at', 'retrievedAt', 'retrieved_at'],
      ),
      temperatureC: _Json.number(
        source,
        ['temperatureC', 'temperature_c', 'tempC', 'temp_c', 'temperature', 'temp'],
      ),
      feelsLikeC: _Json.number(
        source,
        ['feelsLikeC', 'feels_like_c', 'feelsLikeTemperature',
         'feels_like_temperature', 'feelsLike', 'feels_like'],
      ),
      condition: _Json.text(source, ['condition', 'conditions', 'weatherCondition',
          'weather_condition', 'summary']),
      conditionCode: _Json.text(
        source,
        ['conditionCode', 'condition_code', 'weatherCode', 'weather_code'],
      ),
      humidityPercent: _Json.integer(
        source,
        ['humidityPercent', 'humidity_percent', 'humidity'],
      ),
      // ⚠️ Explicitly nullable — must NOT fall back to 0.
      precipitationProbabilityPercent: _Json.integer(
        source,
        ['precipitationProbabilityPercent', 'precipitation_probability_percent',
         'precipitationProbability', 'precipitation_probability',
         'rainProbability', 'rain_probability', 'chanceOfRain', 'chance_of_rain'],
      ),
      rainfallMm: _Json.number(
        source,
        ['rainfallMm', 'rainfall_mm', 'rainfall', 'precipitationMm',
         'precipitation_mm', 'precipitation', 'rainMm', 'rain_mm', 'rain'],
      ),
      windSpeedMps: _Json.number(
        source,
        ['windSpeedMps', 'wind_speed_mps', 'windSpeed', 'wind_speed'],
      ),
      windDirectionDegrees: _Json.number(
        source,
        ['windDirectionDegrees', 'wind_direction_degrees', 'windDirection',
         'wind_direction'],
      ),
      provider: _Json.text(source, ['provider', 'providerId', 'provider_id', 'source']),
      cached: _Json.boolean(source, ['cached', 'isCached', 'is_cached', 'fromCache', 'from_cache']),
      stale: _Json.boolean(source, ['stale', 'isStale', 'is_stale']),
    );
  }

  CurrentWeather copyWith({
    double? latitude,
    double? longitude,
    DateTime? fetchedAt,
    bool? cached,
    bool? stale,
    String? provider,
  }) {
    return CurrentWeather(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      observedAt: observedAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      temperatureC: temperatureC,
      feelsLikeC: feelsLikeC,
      condition: condition,
      conditionCode: conditionCode,
      humidityPercent: humidityPercent,
      precipitationProbabilityPercent: precipitationProbabilityPercent,
      rainfallMm: rainfallMm,
      windSpeedMps: windSpeedMps,
      windDirectionDegrees: windDirectionDegrees,
      provider: provider ?? this.provider,
      cached: cached ?? this.cached,
      stale: stale ?? this.stale,
    );
  }
}

// ════════════════════════════════════════════════════════════
// FORECAST
// ════════════════════════════════════════════════════════════

class HourlyForecast {
  final DateTime? time;
  final double? temperatureC;
  final double? feelsLikeC;
  final String? condition;
  final String? conditionCode;
  final int? humidityPercent;
  final int? precipitationProbabilityPercent;
  final double? rainfallMm;
  final double? windSpeedMps;
  final double? windDirectionDegrees;

  const HourlyForecast({
    this.time,
    this.temperatureC,
    this.feelsLikeC,
    this.condition,
    this.conditionCode,
    this.humidityPercent,
    this.precipitationProbabilityPercent,
    this.rainfallMm,
    this.windSpeedMps,
    this.windDirectionDegrees,
  });

  factory HourlyForecast.fromMap(Map<String, dynamic> map) {
    return HourlyForecast(
      time: _Json.time(
        map,
        ['time', 'dateTime', 'date_time', 'timestamp', 'hour', 'validTime', 'valid_time'],
      ),
      temperatureC: _Json.number(
        map,
        ['temperatureC', 'temperature_c', 'tempC', 'temp_c', 'temperature', 'temp'],
      ),
      feelsLikeC: _Json.number(
        map,
        ['feelsLikeC', 'feels_like_c', 'feelsLikeTemperature',
         'feels_like_temperature', 'feelsLike', 'feels_like'],
      ),
      condition: _Json.text(map, ['condition', 'conditions', 'weatherCondition',
          'weather_condition', 'summary']),
      conditionCode: _Json.text(
        map,
        ['conditionCode', 'condition_code', 'weatherCode', 'weather_code'],
      ),
      humidityPercent:
          _Json.integer(map, ['humidityPercent', 'humidity_percent', 'humidity']),
      // ⚠️ Nullable by contract — null is not zero.
      precipitationProbabilityPercent: _Json.integer(
        map,
        ['precipitationProbabilityPercent', 'precipitation_probability_percent',
         'precipitationProbability', 'precipitation_probability',
         'rainProbability', 'rain_probability', 'chanceOfRain', 'chance_of_rain'],
      ),
      rainfallMm: _Json.number(
        map,
        ['rainfallMm', 'rainfall_mm', 'rainfall', 'precipitationMm',
         'precipitation_mm', 'precipitation', 'rainMm', 'rain_mm', 'rain'],
      ),
      windSpeedMps:
          _Json.number(map, ['windSpeedMps', 'wind_speed_mps', 'windSpeed', 'wind_speed']),
      windDirectionDegrees: _Json.number(
        map,
        ['windDirectionDegrees', 'wind_direction_degrees', 'windDirection',
         'wind_direction'],
      ),
    );
  }
}

class DailyForecast {
  final DateTime? date;
  final String? condition;
  final String? conditionCode;
  final double? tempMaxC;
  final double? tempMinC;
  final int? humidityPercent;
  final int? precipitationProbabilityPercent;
  final double? rainfallMm;
  final double? windSpeedMps;

  const DailyForecast({
    this.date,
    this.condition,
    this.conditionCode,
    this.tempMaxC,
    this.tempMinC,
    this.humidityPercent,
    this.precipitationProbabilityPercent,
    this.rainfallMm,
    this.windSpeedMps,
  });

  factory DailyForecast.fromMap(Map<String, dynamic> map) {
    return DailyForecast(
      date: _Json.time(map, ['date', 'day', 'validDate', 'valid_date', 'time']),
      condition: _Json.text(map, ['condition', 'conditions', 'weatherCondition',
          'weather_condition', 'summary']),
      conditionCode: _Json.text(
        map,
        ['conditionCode', 'condition_code', 'weatherCode', 'weather_code'],
      ),
      tempMaxC: _Json.number(
        map,
        ['tempMaxC', 'temp_max_c', 'temperatureMaxC', 'temperature_max_c',
         'tempMax', 'temp_max', 'maxTemperature', 'max_temperature',
         'maxTemp', 'max_temp', 'high'],
      ),
      tempMinC: _Json.number(
        map,
        ['tempMinC', 'temp_min_c', 'temperatureMinC', 'temperature_min_c',
         'tempMin', 'temp_min', 'minTemperature', 'min_temperature',
         'minTemp', 'min_temp', 'low'],
      ),
      humidityPercent:
          _Json.integer(map, ['humidityPercent', 'humidity_percent', 'humidity']),
      // ⚠️ Nullable by contract — null is not zero.
      precipitationProbabilityPercent: _Json.integer(
        map,
        ['precipitationProbabilityPercent', 'precipitation_probability_percent',
         'precipitationProbability', 'precipitation_probability',
         'rainProbability', 'rain_probability', 'chanceOfRain', 'chance_of_rain'],
      ),
      rainfallMm: _Json.number(
        map,
        ['rainfallMm', 'rainfall_mm', 'rainfall', 'precipitationMm',
         'precipitation_mm', 'precipitation', 'rainMm', 'rain_mm', 'rain'],
      ),
      windSpeedMps:
          _Json.number(map, ['windSpeedMps', 'wind_speed_mps', 'windSpeed', 'wind_speed']),
    );
  }
}

// ════════════════════════════════════════════════════════════
// RESPONSE ENVELOPE
// ════════════════════════════════════════════════════════════

/// Cache/stale metadata returned alongside the payload.
class WeatherMeta {
  final bool cached;
  final bool stale;
  final DateTime? fetchedAt;
  final String? provider;
  final WeatherScope? scope;

  const WeatherMeta({
    this.cached = false,
    this.stale = false,
    this.fetchedAt,
    this.provider,
    this.scope,
  });
}

/// One `app-weather` response, normalized.
class WeatherBundle {
  final CurrentWeather? current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  final WeatherMeta meta;

  const WeatherBundle({
    this.current,
    this.hourly = const [],
    this.daily = const [],
    this.meta = const WeatherMeta(),
  });

  static const WeatherBundle empty = WeatherBundle();

  bool get isEmpty => current == null && hourly.isEmpty && daily.isEmpty;

  bool get stale => meta.stale || (current?.stale ?? false);

  DateTime? get fetchedAt => meta.fetchedAt ?? current?.fetchedAt;

  /// Decode a normalized `app-weather` payload.
  ///
  /// Throws [WeatherException] when the payload carries an error envelope.
  factory WeatherBundle.fromResponse(dynamic payload, {WeatherScope? requestedScope}) {
    final root = _Json.asMap(_Json.coerce(payload));
    if (root == null) {
      throw WeatherException.unavailable;
    }
    _throwIfError(root);

    final merged = _Json.unwrap(root);

    final scope = _Json.text(merged, ['scope']) ?? requestedScope?.name;
    final parsedScope = scope == 'current'
        ? WeatherScope.current
        : scope == 'forecast'
            ? WeatherScope.forecast
            : requestedScope;

    final cache = _Json.asMap(merged['cache']);
    final meta = WeatherMeta(
      cached: _Json.boolean(merged, ['cached', 'isCached', 'is_cached', 'fromCache']) ||
          _Json.boolean(cache ?? <String, dynamic>{}, ['cached', 'isCached', 'is_cached']),
      stale: _Json.boolean(merged, ['stale', 'isStale', 'is_stale']) ||
          _Json.boolean(cache ?? <String, dynamic>{}, ['stale', 'isStale', 'is_stale']),
      fetchedAt: _Json.time(merged, ['fetchedAt', 'fetched_at', 'retrievedAt', 'retrieved_at']) ??
          _Json.time(cache ?? <String, dynamic>{}, ['fetchedAt', 'fetched_at']),
      provider: _Json.text(merged, ['provider', 'providerId', 'provider_id']) ??
          _Json.text(cache ?? <String, dynamic>{}, ['provider']),
      scope: parsedScope,
    );

    // `scope=current` may return the conditions at the top level rather than
    // nested under `current` — fall back to the envelope itself when it holds
    // a temperature.
    final currentMap = _Json.firstMap(
      merged,
      ['current', 'currentWeather', 'current_weather', 'currentConditions'],
    ) ??
        (_Json.number(merged, [
          'temperatureC',
          'temperature_c',
          'tempC',
          'temp_c',
          'temperature',
          'temp',
        ]) !=
                null
            ? merged
            : null);
    final current = currentMap == null
        ? null
        : CurrentWeather.fromMap(currentMap, meta: merged);

    final forecast = _Json.asMap(merged['forecast']) ?? const <String, dynamic>{};
    final hourly = _Json.mapList(
      _Json.first(merged, ['hourly', 'hourlyForecast', 'hourly_forecast']) ??
          _Json.first(forecast, ['hourly', 'hourlyForecast', 'hourly_forecast']),
      HourlyForecast.fromMap,
    );
    final daily = _Json.mapList(
      _Json.first(merged, ['daily', 'dailyForecast', 'daily_forecast', 'dailyForecastData']) ??
          _Json.first(forecast, ['daily', 'dailyForecast', 'daily_forecast']),
      DailyForecast.fromMap,
    );

    return WeatherBundle(
      current: current,
      hourly: hourly,
      daily: daily,
      meta: meta,
    );
  }

  static void _throwIfError(Map<String, dynamic> root) {
    final error = root['error'];
    if (error != null || root['code'] == 'error') {
      throw WeatherException.fromPayload(root);
    }
  }
}

// ════════════════════════════════════════════════════════════
// DECODING HELPERS
// ════════════════════════════════════════════════════════════

class _Json {
  const _Json._();

  /// Turn an `app-weather` payload into a value the decoder understands.
  ///
  /// `functions.invoke` only `jsonDecode`s an `application/json` body, so a
  /// response served with any other content type (a cache HIT returned as
  /// `text/plain`, for example) arrives here as a raw String. A body that was
  /// stringified twice arrives as a JSON-encoded String too. Decode until the
  /// value stops being a String; anything undecodable becomes `null`, which
  /// the caller reports as "unavailable".
  static dynamic coerce(dynamic payload) {
    var value = payload;
    for (var i = 0; i < 3 && value is String; i++) {
      final text = value.trim();
      if (text.isEmpty) return null;
      try {
        value = jsonDecode(text);
      } on FormatException {
        return null;
      }
    }
    return value;
  }

  static Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    return null;
  }

  /// Unwrap a `{"data": {...}}` envelope while keeping root-level fields.
  static Map<String, dynamic> unwrap(Map<String, dynamic> root) {
    final inner = asMap(root['data']);
    if (inner == null) return root;
    return {...root, ...inner};
  }

  static dynamic first(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) return value;
    }
    return null;
  }

  static Map<String, dynamic>? firstMap(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = asMap(map[key]);
      if (value != null) return value;
    }
    return null;
  }

  /// Merge [override] on top of [base] (both optional).
  static Map<String, dynamic> merge(
    Map<String, dynamic>? base,
    Map<String, dynamic>? override,
  ) {
    return {...?base, ...?override};
  }

  static double? number(Map<String, dynamic> map, List<String> keys) {
    final value = first(map, keys);
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static int? integer(Map<String, dynamic> map, List<String> keys) {
    final value = first(map, keys);
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) {
      return int.tryParse(value.trim()) ??
          double.tryParse(value.trim())?.round();
    }
    return null;
  }

  static bool boolean(Map<String, dynamic> map, List<String> keys) {
    final value = first(map, keys);
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static DateTime? time(Map<String, dynamic> map, List<String> keys) {
    final value = first(map, keys);
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    if (value is num) {
      final millis = value.abs() > 100000000000 ? value.toInt() : value.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    }
    return null;
  }

  /// Condition may arrive as a string or as a small normalized object.
  static String? text(Map<String, dynamic> map, List<String> keys) {
    final value = first(map, keys);
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) return value.toString();
    final nested = asMap(value);
    if (nested != null) {
      return text(nested, ['text', 'label', 'description', 'name', 'value']);
    }
    return null;
  }

  /// Accept a bare list, or a list nested under a container key.
  static List<T> mapList<T>(
    dynamic value,
    T Function(Map<String, dynamic>) map,
  ) {
    List<dynamic>? raw;
    if (value is List) {
      raw = value;
    } else {
      final container = asMap(value);
      if (container != null) {
        for (final key in ['data', 'items', 'list', 'values', 'entries']) {
          final inner = container[key];
          if (inner is List) {
            raw = inner;
            break;
          }
        }
      }
    }
    if (raw == null) return <T>[];

    final results = <T>[];
    for (final item in raw) {
      final mapped = asMap(item);
      if (mapped == null) continue;
      results.add(map(mapped));
    }
    return results;
  }
}
