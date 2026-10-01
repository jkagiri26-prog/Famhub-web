import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/ai_assistant/infrastructure/dev_ai_gateway_probe.dart';

void main() {
  group('DevAiGatewayRequest — request construction', () {
    test('sends the fixed Phase 2D body and path', () {
      expect(DevAiGatewayRequest.functionName, 'ai-gateway');
      expect(DevAiGatewayRequest.path, '/functions/v1/ai-gateway');
      expect(DevAiGatewayRequest.body, {
        'task': 'general',
        'input': 'Reply with the word OK.',
      });
      expect(DevAiGatewayRequest.providerHeaderName,
          'x-ai-gateway-test-provider');
    });

    test('Gemini and Normal Gateway omit the provider selector header', () {
      for (final target in [
        DevAiGatewayTarget.gemini,
        DevAiGatewayTarget.normal,
      ]) {
        final headers = DevAiGatewayRequest.buildHeaders(
          target: target,
          accessToken: 'token-123',
        );
        expect(headers.containsKey('x-ai-gateway-test-provider'), isFalse,
            reason: target.name);
        expect(headers['Content-Type'], 'application/json');
        expect(headers['Authorization'], 'Bearer token-123');
        expect(target.providerSelector, isNull);
      }
    });

    test('the four explicit provider selectors are sent verbatim', () {
      const expected = {
        DevAiGatewayTarget.openRouter: 'openrouter',
        DevAiGatewayTarget.groq: 'groq',
        DevAiGatewayTarget.deepSeek: 'deepseek',
        DevAiGatewayTarget.openAI: 'openai',
      };

      for (final entry in expected.entries) {
        final headers = DevAiGatewayRequest.buildHeaders(
          target: entry.key,
          accessToken: 'token-123',
        );
        expect(headers['x-ai-gateway-test-provider'], entry.value,
            reason: entry.key.name);
        expect(headers.length, 3, reason: entry.key.name);
      }
    });

    test('every target is represented exactly once', () {
      expect(DevAiGatewayTarget.values, hasLength(6));
      expect(
        DevAiGatewayTarget.values.where((t) => !t.sendsProviderSelector),
        [DevAiGatewayTarget.gemini, DevAiGatewayTarget.normal],
      );
    });
  });

  group('parseDevAiGatewayResponse — response parsing', () {
    test('a 2xx ok:true payload with output is a success', () {
      final result = parseDevAiGatewayResponse(
        target: DevAiGatewayTarget.gemini,
        statusCode: 200,
        data: {
          'ok': true,
          'request_id': 'req-1',
          'output': 'OK',
        },
        elapsed: const Duration(milliseconds: 420),
      );

      expect(result.succeeded, isTrue);
      expect(result.verdict, 'SUCCESS');
      expect(result.statusCode, 200);
      expect(result.ok, isTrue);
      expect(result.requestId, 'req-1');
      expect(result.output, 'OK');
      expect(result.error, isNull);
      expect(result.elapsedLabel, '420 ms');
    });

    test('ok:false with an error payload is a failure', () {
      final result = parseDevAiGatewayResponse(
        target: DevAiGatewayTarget.groq,
        statusCode: 200,
        data: {
          'ok': false,
          'request_id': 'req-2',
          'error': 'provider unavailable',
        },
        elapsed: const Duration(seconds: 2),
      );

      expect(result.succeeded, isFalse);
      expect(result.ok, isFalse);
      expect(result.error, 'provider unavailable');
      expect(result.elapsedLabel, '2.00 s');
    });

    test('ok:false without an error field still explains itself', () {
      final result = parseDevAiGatewayResponse(
        target: DevAiGatewayTarget.openAI,
        statusCode: 200,
        data: {'ok': false},
        elapsed: Duration.zero,
      );

      expect(result.succeeded, isFalse);
      expect(result.error, contains('ok:false'));
    });

    test('an empty output is a failure even when ok is true', () {
      final result = parseDevAiGatewayResponse(
        target: DevAiGatewayTarget.deepSeek,
        statusCode: 200,
        data: {'ok': true, 'output': '   '},
        elapsed: Duration.zero,
      );

      expect(result.succeeded, isFalse);
      expect(result.hasOutput, isFalse);
    });

    test('a JSON string body is decoded', () {
      final result = parseDevAiGatewayResponse(
        target: DevAiGatewayTarget.openRouter,
        statusCode: 200,
        data: '{"ok":true,"request_id":"r","output":"OK"}',
        elapsed: Duration.zero,
      );

      expect(result.succeeded, isTrue);
      expect(result.output, 'OK');
    });

    test('a non-JSON body is reported as malformed', () {
      final result = parseDevAiGatewayResponse(
        target: DevAiGatewayTarget.gemini,
        statusCode: 200,
        data: '<html>oops</html>',
        elapsed: Duration.zero,
      );

      expect(result.succeeded, isFalse);
      expect(result.transportError, contains('Malformed JSON'));
      expect(result.rawBody, '<html>oops</html>');
    });
  });

  group('parseDevAiGatewayFailure — error classification', () {
    test('a FunctionException keeps the HTTP status and body', () {
      final result = parseDevAiGatewayFailure(
        target: DevAiGatewayTarget.gemini,
        error: const FunctionException(
          status: 401,
          details: {
            'ok': false,
            'error': 'invalid token',
          },
        ),
        elapsed: Duration.zero,
      );

      expect(result.receivedHttpResponse, isTrue);
      expect(result.statusCode, 401);
      expect(result.httpOk, isFalse);
      expect(result.succeeded, isFalse);
      expect(result.error, 'invalid token');
      expect(result.transportError, isNull);
    });

    test('a client timeout is a transport failure', () {
      final result = parseDevAiGatewayFailure(
        target: DevAiGatewayTarget.groq,
        error: TimeoutException('timed out'),
        elapsed: DevAiGatewayRequest.timeout,
      );

      expect(result.receivedHttpResponse, isFalse);
      expect(result.transportError, contains('timeout'));
      expect(result.succeeded, isFalse);
    });

    test('a network failure is a transport failure', () {
      final result = parseDevAiGatewayFailure(
        target: DevAiGatewayTarget.openAI,
        error: Exception('connection refused'),
        elapsed: Duration.zero,
      );

      expect(result.receivedHttpResponse, isFalse);
      expect(result.transportError, contains('Network failure'));
      expect(result.succeeded, isFalse);
    });
  });
}
