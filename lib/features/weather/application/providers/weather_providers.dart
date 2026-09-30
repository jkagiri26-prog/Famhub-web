/// ============================================================
/// WEATHER DATA PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/weather/application/providers/ = weather application layer
///
/// ✅ Responsibilities:
///   - Hold current-conditions and forecast requests
///   - Cache results so widget rebuilds never refetch
///   - Support explicit invalidation for user-triggered refresh only
///
/// ❌ Does NOT:
///   - Poll on a timer (the backend owns the cache TTL:
///     current ≈ 15 min, forecast ≈ 60 min)
///   - Re-implement caching or provider failover
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/infrastructure/weather_service.dart';

/// Weather service bound to the authenticated Supabase client.
final weatherServiceProvider = Provider<WeatherService>(
  (ref) => WeatherService(SupabaseService.instance.client),
);

/// Sentinel used when no usable location exists — resolves to `null`
/// without ever issuing a request.
const WeatherRequestTarget noWeatherTarget = WeatherRequestTarget();

/// Current conditions for a target (small payload → dashboard cards).
///
/// Keyed by [WeatherRequestTarget] so Home, Farm Management and the
/// Weather page share one cached request per location. Watching this
/// provider never refetches just because a widget rebuilt.
final weatherCurrentProvider =
    FutureProvider.family<WeatherBundle?, WeatherRequestTarget>(
  (ref, target) async {
    if (!target.isUsable) return null;
    return ref
        .read(weatherServiceProvider)
        .fetch(target: target, scope: WeatherScope.current);
  },
);

/// Hourly + daily forecast for a target (larger payload → weather page).
final weatherForecastProvider =
    FutureProvider.family<WeatherBundle?, WeatherRequestTarget>(
  (ref, target) async {
    if (!target.isUsable) return null;
    return ref
        .read(weatherServiceProvider)
        .fetch(target: target, scope: WeatherScope.forecast);
  },
);
