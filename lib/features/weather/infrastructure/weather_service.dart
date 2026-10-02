/// ============================================================
/// WEATHER SERVICE (EDGE FUNCTION CLIENT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/weather/infrastructure/ = weather data layer
///
/// ✅ Responsibilities:
///   - Invoke the deployed `app-weather` Edge Function
///   - Use the authenticated Supabase session (inherited from the client)
///   - Send `location_id` OR `latitude`/`longitude` plus `scope`
///   - Decode the normalized, provider-independent response
///   - Surface user-safe errors
///
/// ❌ Does NOT:
///   - Call WeatherAPI.com or hold its API key
///   - Know provider-specific request/response details
///   - Query `weather.*` tables directly
///   - Implement or duplicate any cache/TTL logic (backend owns it)
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/domain/weather_exception.dart';

class WeatherService {
  final SupabaseClient _client;

  WeatherService(this._client);

  /// Deployed Edge Function (v2, JWT verification enabled).
  static const String functionName = 'app-weather';

  /// Fetch a normalized weather payload.
  ///
  /// Request shape (exactly one location form):
  ///   {"location_id": "<uuid>", "scope": "current" | "forecast"}
  ///   {"latitude": 1.23, "longitude": 4.56, "scope": "current" | "forecast"}
  Future<WeatherBundle> fetch({
    required WeatherRequestTarget target,
    required WeatherScope scope,
  }) async {
    if (!target.isUsable) {
      throw WeatherException.noLocation;
    }

    final body = <String, dynamic>{'scope': scope.name};
    if (target.hasLocationId) {
      body['location_id'] = target.locationId!.trim();
    } else {
      body['latitude'] = target.latitude;
      body['longitude'] = target.longitude;
    }

    final dynamic payload;
    try {
      // TEMPORARY diagnostic logging (safe: locator + scope + status only —
      // never tokens, Authorization headers or API keys). Remove with the
      // Kisumu override when the diagnostic run is done.
      debugPrint(
        '[weather] → $functionName scope=${scope.name} '
        'locator=${target.hasLocationId ? 'location_id=${target.locationId}' : 'coordinates'}',
      );
      // `invoke` attaches the current session access token automatically.
      final response = await _client.functions.invoke(
        functionName,
        body: body,
      );
      payload = response.data;
      debugPrint('[weather] ← HTTP ${response.status} ok scope=${scope.name}');
    } on FunctionException catch (error) {
      final safe = WeatherException.fromFunction(error);
      debugPrint(
        '[weather] ← HTTP ${error.status} code=${safe.code ?? 'unknown'} '
        'message=${safe.message}',
      );
      throw safe;
    } on WeatherException {
      rethrow;
    } catch (error) {
      // Network/DNS/timeouts — never surfaced as a raw exception.
      debugPrint('[weather] ← transport error (${error.runtimeType})');
      throw WeatherException.unavailable;
    }

    try {
      return WeatherBundle.fromResponse(payload, requestedScope: scope);
    } on WeatherException {
      rethrow;
    } catch (_) {
      throw WeatherException.unavailable;
    }
  }
}
