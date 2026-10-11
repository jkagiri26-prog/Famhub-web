/// ============================================================
/// AGRI CONNECT — DISCUSSION MEDIA CONTEXT CONTRACT TESTS
/// ============================================================
///
/// Pins the context values the deployed media edge functions are called
/// with, by running the real data source against a local HTTP server and
/// inspecting the exact request bodies:
///
///   - upload_media       must receive the established value "discussions"
///                        (any other value is rejected, which failed the
///                        edit dialog's media phase after the text save)
///   - media_get_by_context must receive the proven display alias
///                        "agri_connect_discussion"
///
/// These are the two contexts that regressed together in 81a10f1 when a
/// single shared constant was changed for both functions.
/// ============================================================
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/agri_connect_media.dart';

Uint8List _imageBytes() => Uint8List.fromList(utf8.encode('probe-image'));

void main() {
  group('discussion media context constants', () {
    test('upload context is the established `discussions` value', () {
      expect(AgriConnectMediaDataSource.discussionsContext, 'discussions');
    });

    test('lookup context is the proven display alias', () {
      expect(
        AgriConnectMediaDataSource.discussionLookupContext,
        'agri_connect_discussion',
      );
    });
  });

  group('media edge-function request capture', () {
    late HttpServer server;
    final List<String> captures = [];

    setUpAll(() async {
      HttpOverrides.global = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        final body = await utf8.decoder.bind(request).join();
        captures.add('${request.method} ${request.uri.path}||$body');
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'success': true,
            'id': 'uploaded-file-id',
            'files': [
              {'id': 'uploaded-file-id', 'path': 'media/probe.webp'},
            ],
          }),
        );
        await request.response.close();
      });
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    setUp(() => captures.clear());

    AgriConnectMediaDataSource dataSource() => AgriConnectMediaDataSource(
      SupabaseClient('http://127.0.0.1:${server.port}', 'local-test-jwt'),
    );

    test(
      'uploadDiscussionImage sends context=discussions to upload_media',
      () async {
        final payload = await dataSource().uploadDiscussionImage(
          bytes: _imageBytes(),
          fileName: 'probe.webp',
          discussionId: '11111111-2222-3333-4444-555555555555',
        );

        expect(payload, isA<Map>());
        expect(captures, hasLength(1));
        final capture = captures.single;
        expect(capture, startsWith('POST /functions/v1/upload_media'));
        expect(
          capture,
          contains('name="context"\r\n\r\ndiscussions'),
          reason: 'upload_media only accepts the established context value',
        );
        expect(
          capture,
          isNot(contains('agri_connect_discussion')),
          reason: 'the lookup alias must never be sent to upload_media',
        );
        expect(capture, contains('name="file"'));
      },
    );

    test(
      'fetchMediaEntries sends the display alias to media_get_by_context',
      () async {
        await dataSource().fetchMediaEntries(
          context: AgriConnectMediaDataSource.discussionLookupContext,
          contextId: '11111111-2222-3333-4444-555555555555',
        );

        expect(captures, hasLength(1));
        final capture = captures.single;
        expect(capture, startsWith('POST /functions/v1/media_get_by_context'));
        expect(capture, contains('"context":"agri_connect_discussion"'));
        expect(
          capture,
          isNot(contains('"context":"discussions"')),
          reason: 'lookup keeps the alias that makes image display work',
        );
      },
    );
  });
}
