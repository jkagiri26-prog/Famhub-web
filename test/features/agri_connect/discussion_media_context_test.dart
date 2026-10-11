/// ============================================================
/// AGRI CONNECT — DISCUSSION MEDIA CONTEXT CONTRACT TESTS
/// ============================================================
///
/// Pins the exact backend calls the media data source makes, by running
/// the real data source against a local HTTP server and inspecting the
/// request paths and bodies:
///
///   - upload_media         must receive the established value "discussions"
///                          (any other value is rejected, which failed the
///                          edit dialog's media phase after the text save)
///   - media_get_by_context must receive the proven display alias
///                          "agri_connect_discussion"
///   - delete_discussion_media must be called as the RPC
///                          `agri_connect.delete_discussion_media` with the
///                          argument `p_file_id` — never the listing-specific
///                          `delete_media` edge function
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

const String _fileId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

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
    var rpcStatusCode = 200;
    Object rpcBody = const {'storage_retained': true};

    setUpAll(() async {
      HttpOverrides.global = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        final body = await utf8.decoder.bind(request).join();
        captures.add('${request.method} ${request.uri.path}||$body');
        final isRpc = request.uri.path.contains('/rpc/');
        request.response.statusCode = isRpc ? rpcStatusCode : 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            isRpc
                ? rpcBody
                : {
                    'success': true,
                    'id': 'uploaded-file-id',
                    'files': [
                      {'id': 'uploaded-file-id', 'path': 'media/probe.webp'},
                    ],
                  },
          ),
        );
        await request.response.close();
      });
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    setUp(() {
      captures.clear();
      rpcStatusCode = 200;
      rpcBody = const {'storage_retained': true};
    });

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

    test(
      'deleteDiscussionMedia calls the agri_connect RPC with p_file_id',
      () async {
        await dataSource().deleteDiscussionMedia(_fileId);

        expect(captures, hasLength(1));
        final capture = captures.single;
        expect(
          capture,
          startsWith('POST /rest/v1/rpc/delete_discussion_media'),
          reason:
              'removal must go through the database RPC, not an edge '
              'function',
        );
        expect(capture, contains('"p_file_id":"$_fileId"'));
        expect(
          capture,
          isNot(contains('/functions/v1/delete_media')),
          reason:
              'the listing-specific delete_media edge function must never '
              'be used for discussion images',
        );
      },
    );

    test(
      'deleteDiscussionMedia accepts the storage_retained success payload',
      () async {
        rpcBody = const {'storage_retained': true, 'file_id': _fileId};
        await expectLater(
          dataSource().deleteDiscussionMedia(_fileId),
          completes,
        );
      },
    );

    test(
      'deleteDiscussionMedia surfaces the database error details on failure',
      () async {
        rpcStatusCode = 400;
        rpcBody = const {
          'code': 'P0001',
          'message': 'cannot remove the last attached image',
          'details': null,
          'hint': null,
        };
        await expectLater(
          dataSource().deleteDiscussionMedia(_fileId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('Media removal failed'),
                contains('cannot remove the last attached image'),
              ),
            ),
          ),
        );
      },
    );

    test('deleteDiscussionMedia rejects a success:false payload', () async {
      rpcBody = const {'success': false, 'error': 'not authorized'};
      await expectLater(
        dataSource().deleteDiscussionMedia(_fileId),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('not authorized'),
          ),
        ),
      );
    });
  });
}
