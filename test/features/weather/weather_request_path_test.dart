/// ⚠️ TEMPORARY DIAGNOSTIC TEST — delete together with
/// `kWeatherDiagnosticOverrideEnabled` / `kWeatherDiagnosticOverrideLocationId`
/// in `weather_location_provider.dart` when the Kisumu run is done.
///
/// Proves, at runtime (not at compile time), that the existing Weather
/// request path emits exactly the payload the deployed `app-weather`
/// function accepts:
///   {"location_id": "067f88d7-0f4c-43e8-8e7f-d4c46733810e", "scope": "current"}
///   {"location_id": "067f88d7-0f4c-43e8-8e7f-d4c46733810e", "scope": "forecast"}
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/weather/application/providers/weather_location_provider.dart';
import 'package:famhub_app/features/weather/domain/models/weather_models.dart';
import 'package:famhub_app/features/weather/infrastructure/weather_service.dart';

const String _kisumuId = '067f88d7-0f4c-43e8-8e7f-d4c46733810e';

/// Structurally valid, non-secret JWT (role anon) used only so the client
/// accepts it locally — no real credential is involved.
String _fakeJwt() {
  String seg(Object value) =>
      base64Url.encode(utf8.encode(value.toString())).replaceAll('=', '');
  return '${seg('{"alg":"HS256","typ":"JWT"}')}.'
      '${seg('{"role":"anon","iss":"local-test"}')}.local-test-signature';
}

void main() {
  group('temporary Kisumu override', () {
    test('weatherLocationProvider resolves the Kisumu location id', () {
      if (!kWeatherDiagnosticOverrideEnabled) return;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final candidate = container.read(weatherLocationProvider);
      expect(candidate, isNotNull);
      expect(candidate!.locationId, _kisumuId);
      expect(candidate.target.isUsable, isTrue);
      expect(candidate.target.latitude, isNull);
      expect(candidate.target.longitude, isNull);
    });
  });

  group('WeatherService request path (real HTTP against a local stub)', () {
    late HttpServer server;
    late List<Map<String, String>> requests;

    setUpAll(() async {
      // flutter_test installs an HttpOverrides that blocks real sockets.
      HttpOverrides.global = null;
      requests = <Map<String, String>>[];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        final raw = await utf8.decoder.bind(request).join();
        requests.add(<String, String>{
          'method': request.method,
          'path': request.uri.path,
          'body': raw,
        });
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(<String, dynamic>{
          'scope': 'current',
          'current': <String, dynamic>{
            'temperatureC': 27.5,
            'condition': 'Sunny',
          },
          'hourly': <dynamic>[],
          'daily': <dynamic>[],
          'cache': <String, dynamic>{'cached': false, 'stale': false},
        }));
        await request.response.close();
      });
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    setUp(() => requests.clear());

    SupabaseClient client() => SupabaseClient(
          'http://127.0.0.1:${server.port}',
          _fakeJwt(),
        );

    test('sends exactly {"location_id", "scope":"current"}', () async {
      if (!kWeatherDiagnosticOverrideEnabled) return;

      final target = ProviderContainer().read(weatherLocationProvider)!.target;
      final bundle = await WeatherService(client())
          .fetch(target: target, scope: WeatherScope.current);

      // Real response was decoded end-to-end.
      expect(bundle.current?.temperatureC, 27.5);
      expect(bundle.current?.condition, 'Sunny');

      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request['method'], 'POST');
      expect(request['path'], '/functions/v1/app-weather');

      final body = jsonDecode(request['body']!) as Map<String, dynamic>;
      expect(body, <String, dynamic>{
        'location_id': _kisumuId,
        'scope': 'current',
      });
      expect(body.keys, unorderedEquals(<String>['location_id', 'scope']));
    });

    test('the existing forecast path sends {"location_id", "scope":"forecast"}',
        () async {
      if (!kWeatherDiagnosticOverrideEnabled) return;

      final target = ProviderContainer().read(weatherLocationProvider)!.target;
      await WeatherService(client())
          .fetch(target: target, scope: WeatherScope.forecast);

      expect(requests, hasLength(1));
      final body = jsonDecode(requests.single['body']!) as Map<String, dynamic>;
      expect(body, <String, dynamic>{
        'location_id': _kisumuId,
        'scope': 'forecast',
      });
    });
  });
}
