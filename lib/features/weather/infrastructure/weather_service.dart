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
      // `invoke` attaches the current session access token automatically.
      final response = await _client.functions.invoke(
        functionName,
        body: body,
      );
      payload = response.data;
    } on FunctionException catch (error) {
      throw WeatherException.fromFunction(error);
    } on WeatherException {
      rethrow;
    } catch (_) {
      // Network/DNS/timeouts — never surfaced as a raw exception.
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
