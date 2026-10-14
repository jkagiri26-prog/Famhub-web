/// ============================================================
/// AI GATEWAY SERVICE (EDGE FUNCTION CLIENT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/ai_assistant/infrastructure/ = AI data layer
///
/// ✅ Responsibilities:
///   - Invoke the deployed `ai-gateway` Edge Function
///   - Use the authenticated Supabase session (inherited from the client)
///   - Send the canonical `general_text` task with the user's prompt
///   - Optionally forward the backend's developer provider selector
///   - Decode the gateway envelope into a success/failure result
///   - Classify client-side transport failures (timeout / network)
///
/// ❌ Does NOT:
///   - Hold or request any provider API key
///   - Route, select or fall back between providers (the backend owns it)
///   - Persist prompts, chats or usage
///   - Surface raw provider text to the UI
/// ============================================================
library;

import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

class AiGatewayService {
  AiGatewayService(this._client);

  final SupabaseClient _client;

  /// Invoked as `<project>/functions/v1/ai-gateway`.
  static const String functionName = 'ai-gateway';

  /// Backend developer-only provider selector. `null`/omitted means the
  /// gateway owns provider selection and fallback.
  static const String providerHeaderName = 'x-ai-gateway-test-provider';

  /// The gateway enforces an approximately 30s overall provider budget.
  /// The client waits slightly longer so the developer sees the gateway's
  /// own timeout diagnostic instead of a client-side abort.
  static const Duration timeout = Duration(seconds: 35);

  /// Canonical task. The backend maps every other value onto `general_text`,
  /// so this is the only task the client needs to know about.
  static const String task = 'general_text';

  /// Explicit selector values accepted by the gateway. Gemini is deliberately
  /// absent: it is the normal first-choice provider and has no selector.
  static const List<String> providerSelectors = <String>[
    'openrouter',
    'groq',
    'deepseek',
    'openai',
  ];

  /// Send one prompt through the gateway.
  ///
  /// Never throws — every outcome is reported as an [AiGatewayResult] so the
  /// UI can show the exact diagnostic.
  Future<AiGatewayResult> complete({
    required String prompt,
    String? providerSelector,
  }) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return const AiGatewayResult.failure(
        elapsed: Duration.zero,
        code: 'empty_prompt',
        message: 'Enter a prompt first.',
      );
    }

    final stopwatch = Stopwatch()..start();

    try {
      // `invoke` attaches the current session access token automatically.
      final response = await _client.functions.invoke(
        functionName,
        headers: <String, String>{
          if (providerSelector != null &&
              providerSelector.isNotEmpty &&
              providerSelectors.contains(providerSelector))
            providerHeaderName: providerSelector,
        },
        body: <String, dynamic>{
          'task': task,
          'input': <String, dynamic>{'prompt': trimmed},
        },
      ).timeout(timeout);

      stopwatch.stop();
      return _interpret(
        statusCode: response.status,
        data: response.data,
        elapsed: stopwatch.elapsed,
      );
    } on FunctionException catch (error) {
      stopwatch.stop();
      return _interpret(
        statusCode: error.status,
        data: error.details,
        elapsed: stopwatch.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      return AiGatewayResult.failure(
        elapsed: stopwatch.elapsed,
        code: 'client_timeout',
        message:
            'The gateway did not respond within ${timeout.inSeconds}s — '
            'no HTTP response was received.',
      );
    } catch (error) {
      stopwatch.stop();
      // Nothing reached the gateway, so there is no HTTP status. The runtime
      // type is kept because a browser CORS rejection and a dead host look
      // identical as a generic catch; surfacing them is the only way to tell
      // them apart from this screen.
      final detail = error.toString();
      return AiGatewayResult.failure(
        elapsed: stopwatch.elapsed,
        code: 'transport_error',
        message:
            'The request never left the browser — no HTTP response was '
            'received. A rejected CORS preflight reports this way. '
            'Runtime: ${error.runtimeType}.',
        rawBody: detail,
      );
    }
  }

  /// Turn a gateway envelope (or a platform-level error body) into a result.
  AiGatewayResult _interpret({
    required int statusCode,
    required dynamic data,
    required Duration elapsed,
  }) {
    final Map<String, dynamic>? json = _asJson(data);

    if (json == null) {
      return AiGatewayResult.failure(
        elapsed: elapsed,
        statusCode: statusCode,
        code: 'invalid_response',
        message: 'The gateway response could not be decoded.',
        rawBody: _asText(data),
      );
    }

    final dynamic errorNode = json['error'];
    String? code;
    String? message;
    if (errorNode is Map) {
      code = errorNode['code']?.toString();
      message = errorNode['message']?.toString();
    } else if (errorNode != null) {
      message = errorNode.toString();
    }

    final bool? ok = json['ok'] is bool ? json['ok'] as bool : null;
    final String? requestId = json['request_id']?.toString();

    if (ok == true) {
      final String output = json['output']?.toString() ?? '';
      if (output.trim().isEmpty) {
        return AiGatewayResult.failure(
          elapsed: elapsed,
          statusCode: statusCode,
          requestId: requestId,
          code: 'empty_output',
          message: 'The gateway reported success but returned no text.',
        );
      }
      return AiGatewayResult.success(
        elapsed: elapsed,
        statusCode: statusCode,
        requestId: requestId,
        output: output,
      );
    }

    return AiGatewayResult.failure(
      elapsed: elapsed,
      statusCode: statusCode,
      requestId: requestId,
      code: code ?? 'unknown_error',
      message: message ??
          (ok == false
              ? 'The gateway returned ok:false with no error field.'
              : 'The gateway response did not contain an ok field.'),
      rawBody: _asText(data),
    );
  }

  // ── internals ────────────────────────────────────────────

  static Map<String, dynamic>? _asJson(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((key, entry) => MapEntry(key.toString(), entry));
        }
      } catch (_) {
        // A malformed body is reported as an undecodable response, not thrown.
        return null;
      }
    }
    return null;
  }

  static String? _asText(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }
}

/// ============================================================
/// AI GATEWAY RESULT
/// ============================================================
///
/// Carries the full gateway diagnostic so a developer can see exactly what
/// happened. This is a *developer* surface: raw `code`/`message` are shown
/// deliberately, because the point of this screen is testing the gateway.
/// ============================================================
class AiGatewayResult {
  const AiGatewayResult.success({
    required this.elapsed,
    required this.statusCode,
    required this.requestId,
    required this.output,
  })  : succeeded = true,
        code = null,
        message = null,
        rawBody = null;

  const AiGatewayResult.failure({
    required this.elapsed,
    this.statusCode,
    required this.code,
    required this.message,
    this.requestId,
    this.rawBody,
  })  : succeeded = false,
        output = null;

  final bool succeeded;
  final int? statusCode;
  final String? requestId;
  final String? output;
  final String? code;
  final String? message;
  final Duration elapsed;
  final String? rawBody;

  String get elapsedLabel {
    final int ms = elapsed.inMilliseconds;
    if (ms < 1000) return '$ms ms';
    return '${(ms / 1000).toStringAsFixed(2)} s';
  }
}
