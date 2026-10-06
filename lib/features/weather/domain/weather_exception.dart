/// ============================================================
/// WEATHER EXCEPTION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/weather/domain/ = weather domain layer
///
/// ✅ Responsibilities:
///   - Translate backend/function failures into user-safe messages
///   - Preserve machine-readable code + HTTP status for diagnostics
///
/// ❌ Does NOT:
///   - Carry provider (WeatherAPI) error text to the UI
///   - Expose raw function payloads to the user
/// ============================================================
library;

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class WeatherException implements Exception {
  /// User-safe message. Never contains provider/API technical detail.
  final String message;

  /// Backend error code, when the function supplied one.
  final String? code;

  /// HTTP status returned by the Edge Function, when available.
  final int? status;

  const WeatherException(this.message, {this.code, this.status});

  /// No usable weather location is available on this device/session.
  static const WeatherException noLocation = WeatherException(
    'No weather location is available yet.',
  );

  /// Authentication is missing/expired — the function requires a session.
  static const WeatherException unauthenticated = WeatherException(
    'Sign in to see the weather for this location.',
    code: 'unauthenticated',
    status: 401,
  );

  /// The request was rejected (malformed body, unknown location, …).
  static const WeatherException invalidRequest = WeatherException(
    'We could not load weather for this location.',
    code: 'invalid_request',
    status: 400,
  );

  /// Generic backend/provider outage.
  static const WeatherException unavailable = WeatherException(
    'Weather is temporarily unavailable. Please try again.',
    code: 'unavailable',
  );

  /// Build from a `functions.invoke` failure.
  factory WeatherException.fromFunction(FunctionException error) {
    final code = _payloadCode(_decode(error.details));
    return WeatherException(
      _messageFor(status: error.status, code: code),
      code: code,
      status: error.status,
    );
  }

  /// Build from an `{"error": {"code", "message"}}` payload returned with a
  /// success status (defensive — some functions report failures this way).
  factory WeatherException.fromPayload(dynamic payload) {
    final decoded = _decode(payload);
    final code = _payloadCode(decoded);
    final status = decoded is Map && decoded['status'] is num
        ? (decoded['status'] as num).toInt()
        : null;
    return WeatherException(
      _messageFor(status: status, code: code),
      code: code,
      status: status,
    );
  }

  /// Error bodies can arrive as a raw String when the content type is not
  /// `application/json`; decode them before reading `code` / `status`.
  static dynamic _decode(dynamic payload) {
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

  static String? _payloadCode(dynamic payload) {
    if (payload is! Map) return null;
    final error = payload['error'];
    final raw = error is Map ? error['code'] : payload['code'];
    return raw?.toString();
  }

  static String _messageFor({int? status, String? code}) {
    final normalized = (code ?? '').toLowerCase();
    if (status == 401 ||
        normalized.contains('unauth') ||
        normalized.contains('no_auth')) {
      return unauthenticated.message;
    }
    if (status == 400 ||
        status == 404 ||
        status == 422 ||
        normalized.contains('invalid') ||
        normalized.contains('not_found') ||
        normalized.contains('bad_request')) {
      return invalidRequest.message;
    }
    return unavailable.message;
  }

  @override
  String toString() => message;
}
