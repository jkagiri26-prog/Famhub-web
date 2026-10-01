/// ============================================================
/// DEV AI GATEWAY PROBE (PHASE 2D — TEMPORARY DEVELOPER TEST)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/ai_assistant/infrastructure/ = AI data layer
///
/// ⚠️ TEMPORARY: Phase 2D developer-only proof of the deployed
///   `ai-gateway` Edge Function from the real authenticated app.
///   This is NOT the permanent AI/Extension Services architecture.
///
/// ✅ Responsibilities:
///   - Describe the six Phase 2D probe targets and their
///     `x-ai-gateway-test-provider` selector value
///   - Build the exact request contract (headers + body)
///   - Parse a gateway response into developer diagnostics
///   - Classify transport failures (timeout / network / CORS)
///
/// ❌ Does NOT:
///   - Hold or request any provider API key
///   - Route, select or fall back between providers (backend owns it)
///   - Talk to Supabase itself (the caller does the `invoke`)
///   - Persist anything
/// ============================================================
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================================
/// PROBE TARGET
/// ============================================================
///
/// Each entry maps 1:1 to a button on the developer screen.
/// [providerSelector] is the value sent in
/// `x-ai-gateway-test-provider`; `null` means the header is
/// omitted entirely (Gemini / normal gateway path).
/// ============================================================
enum DevAiGatewayTarget {
  gemini('Test Gemini', 'Gemini — no provider selector', null),
  normal('Test Normal Gateway', 'Normal gateway path — no provider selector', null),
  openRouter('Test OpenRouter', 'OpenRouter', 'openrouter'),
  groq('Test Groq', 'Groq', 'groq'),
  deepSeek('Test DeepSeek', 'DeepSeek', 'deepseek'),
  openAI('Test OpenAI', 'OpenAI', 'openai');

  const DevAiGatewayTarget(this.buttonLabel, this.description, this.providerSelector);

  final String buttonLabel;
  final String description;

  /// Value for `x-ai-gateway-test-provider`, or null to omit the header.
  final String? providerSelector;

  bool get sendsProviderSelector => providerSelector != null;
}

/// ============================================================
/// REQUEST CONTRACT
/// ============================================================
///
/// The single place that defines exactly what Phase 2D sends.
/// Deliberately fixed — the request contract must not change.
/// ============================================================
class DevAiGatewayRequest {
  DevAiGatewayRequest._();

  /// Invoked as `<project>/functions/v1/ai-gateway`.
  static const String functionName = 'ai-gateway';

  /// The full path shown to the developer for verification.
  static const String path = '/functions/v1/ai-gateway';

  /// Backend developer-only provider selector header.
  static const String providerHeaderName = 'x-ai-gateway-test-provider';

  /// Fixed Phase 2D body.
  static const Map<String, String> body = {
    'task': 'general',
    'input': 'Reply with the word OK.',
  };

  /// The gateway enforces an approximately 30s overall execution budget.
  /// The client waits slightly longer so the developer sees the gateway's
  /// own timeout/diagnostic instead of a client-side abort.
  static const Duration timeout = Duration(seconds: 35);

  /// Headers for one probe. The access token is the current Supabase
  /// session token supplied by the caller — never an API key.
  static Map<String, String> buildHeaders({
    required DevAiGatewayTarget target,
    required String accessToken,
  }) {
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      if (target.providerSelector != null)
        providerHeaderName: target.providerSelector!,
    };
  }
}

/// ============================================================
/// PROBE RESULT
/// ============================================================
class DevAiGatewayResult {
  const DevAiGatewayResult({
    required this.target,
    required this.elapsed,
    this.statusCode,
    this.ok,
    this.requestId,
    this.output,
    this.error,
    this.rawBody,
    this.transportError,
    this.corsSuspected = false,
  });

  final DevAiGatewayTarget target;
  final Duration elapsed;
  final int? statusCode;
  final bool? ok;
  final String? requestId;
  final String? output;
  final String? error;

  /// Decoded body as received, for malformed/partial payloads.
  final String? rawBody;

  /// Set when the request never produced an HTTP response
  /// (network failure, timeout, CORS preflight rejection).
  final String? transportError;

  /// True when the failure looks like a browser CORS/preflight rejection.
  final bool corsSuspected;

  bool get receivedHttpResponse => statusCode != null;

  bool get httpOk => statusCode != null && statusCode! >= 200 && statusCode! < 300;

  bool get hasOutput => output != null && output!.trim().isNotEmpty;

  /// The full success definition for Phase 2D:
  /// 2xx + `ok:true` + non-empty `output`.
  bool get succeeded =>
      transportError == null && httpOk && ok == true && hasOutput;

  String get verdict => succeeded ? 'SUCCESS' : 'FAILED';

  String get elapsedLabel {
    final ms = elapsed.inMilliseconds;
    if (ms < 1000) return '$ms ms';
    return '${(ms / 1000).toStringAsFixed(2)} s';
  }
}

/// ============================================================
/// RESPONSE PARSING
/// ============================================================

/// Builds a [DevAiGatewayResult] from a decoded gateway payload.
DevAiGatewayResult parseDevAiGatewayResponse({
  required DevAiGatewayTarget target,
  required int statusCode,
  required dynamic data,
  required Duration elapsed,
}) {
  final Map<String, dynamic>? json = _asJson(data);

  if (json == null) {
    return DevAiGatewayResult(
      target: target,
      elapsed: elapsed,
      statusCode: statusCode,
      transportError: 'Malformed JSON: the gateway response could not be decoded.',
      rawBody: _asText(data),
    );
  }

  final okValue = json['ok'];
  final errorValue = json['error'];
  final requestIdValue = json['request_id'] ?? json['requestId'];
  final outputValue = json['output'];

  // `ok:false` with no explicit error still needs an explanation on screen.
  String? error;
  if (errorValue != null && errorValue.toString().trim().isNotEmpty) {
    error = _asText(errorValue);
  } else if (okValue == false) {
    error = 'Gateway returned ok:false with no error field.';
  }

  return DevAiGatewayResult(
    target: target,
    elapsed: elapsed,
    statusCode: statusCode,
    ok: okValue is bool ? okValue : null,
    requestId: requestIdValue?.toString(),
    output: _asText(outputValue),
    error: error,
    rawBody: _asText(data),
  );
}

/// Classifies an exception thrown while invoking the gateway.
DevAiGatewayResult parseDevAiGatewayFailure({
  required DevAiGatewayTarget target,
  required Object error,
  required Duration elapsed,
}) {
  // A non-2xx HTTP response: `functions.invoke` throws FunctionException
  // carrying the status code and the decoded body.
  if (error is FunctionException) {
    final parsed = parseDevAiGatewayResponse(
      target: target,
      statusCode: error.status,
      data: error.details,
      elapsed: elapsed,
    );
    return DevAiGatewayResult(
      target: target,
      elapsed: elapsed,
      statusCode: error.status,
      ok: parsed.ok,
      requestId: parsed.requestId,
      output: parsed.output,
      error: parsed.error ??
          'HTTP ${error.status}${error.reasonPhrase == null ? '' : ' ${error.reasonPhrase}'}',
      rawBody: parsed.rawBody,
    );
  }

  if (error is TimeoutException) {
    return DevAiGatewayResult(
      target: target,
      elapsed: elapsed,
      transportError:
          'Client timeout after ${DevAiGatewayRequest.timeout.inSeconds}s — '
          'no HTTP response was received.',
    );
  }

  if (error is http.ClientException) {
    return DevAiGatewayResult(
      target: target,
      elapsed: elapsed,
      transportError: 'Network failure: ${error.message}',
      corsSuspected: kIsWeb && _looksLikeCorsRejection(error.message),
    );
  }

  final description = 'Network failure: $error';
  return DevAiGatewayResult(
    target: target,
    elapsed: elapsed,
    transportError: description,
    corsSuspected: kIsWeb && _looksLikeCorsRejection(description),
  );
}

// ── internals ──────────────────────────────────────────────

Map<String, dynamic>? _asJson(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      return null;
    }
    return null;
  }
  return null;
}

String? _asText(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  try {
    return jsonEncode(value);
  } catch (_) {
    return value.toString();
  }
}

/// True when the browser refused the request before it was sent —
/// the classic symptom of a CORS preflight rejecting the custom
/// `x-ai-gateway-test-provider` header.
bool _looksLikeCorsRejection(String message) {
  final lower = message.toLowerCase();
  return lower.contains('xmlhttprequest') ||
      lower.contains('cors') ||
      lower.contains('preflight') ||
      lower.contains('access-control') ||
      lower.contains('failed to fetch') ||
      lower.contains('networkerror');
}
