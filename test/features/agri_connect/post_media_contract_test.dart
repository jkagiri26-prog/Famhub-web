/// ============================================================
/// AGRI CONNECT — COMMENT (POST) MEDIA CONTRACT TESTS
/// ============================================================
///
/// Pins the exact backend calls the media data source makes for comment
/// / reply images, by running the real data source against a local HTTP
/// server and inspecting the request paths and bodies:
///
///   - upload_media            must receive context "agri_connect_post"
///                              with context_id = the created post's uuid
///                              (single context shared with lookup; the
///                              uploader reserves the slot and registers
///                              `agri_connect.post_media` itself)
///   - media_get_by_context    must receive "agri_connect_post" for
///                              display lookups keyed by the post id
///   - remove_post_media       must be called as the RPC
///                              `agri_connect.remove_post_media(p_post_id,
///                              p_file_id)` — never the listing-specific
///                              `delete_media` edge function
///
/// Also pins the upload failure contract: `success: false`, non-Map and
/// HTTP-error payloads must throw — nothing is treated as attached
/// unless the backend confirmed it.
/// ============================================================
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/agri_connect/infrastructure/data_sources/agri_connect_media.dart';

Uint8List _imageBytes() => Uint8List.fromList(utf8.encode('probe-image'));

const String _postId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const String _fileId = '11111111-2222-3333-4444-555555555555';

/// Response shape `upload_media` is documented to return on success.
const Map<String, Object> _uploadOk = {
  'success': true,
  'id': 'uploaded-file-id',
  'files': [
    {'id': 'uploaded-file-id', 'path': 'media/probe.webp'},
  ],
};

void main() {
  group('post media context constants', () {
    test('upload and lookup share the single agri_connect_post context', () {
      expect(AgriConnectMediaDataSource.postContext, 'agri_connect_post');
    });
  });

  group('comment media request capture', () {
    late HttpServer server;
    final List<String> captures = [];
    var uploadStatusCode = 200;
    Object uploadBody = _uploadOk;
    var lookupStatusCode = 200;
    Object lookupBody = _uploadOk;
    var rpcStatusCode = 200;
    Object rpcBody = const {'storage_retained': true};

    setUpAll(() async {
      HttpOverrides.global = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((HttpRequest request) async {
        final body = await utf8.decoder.bind(request).join();
        captures.add('${request.method} ${request.uri.path}||$body');
        final path = request.uri.path;
        final isUpload = path.contains('/upload_media');
        final isLookup = path.contains('/media_get_by_context');
        final isRpc = path.contains('/rpc/');
        request.response.statusCode = isUpload
            ? uploadStatusCode
            : isLookup
            ? lookupStatusCode
            : isRpc
            ? rpcStatusCode
            : 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            isUpload
                ? uploadBody
                : isLookup
                ? lookupBody
                : isRpc
                ? rpcBody
                : const {},
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
      uploadStatusCode = 200;
      uploadBody = _uploadOk;
      lookupStatusCode = 200;
      lookupBody = _uploadOk;
      rpcStatusCode = 200;
      rpcBody = const {'storage_retained': true};
    });

    AgriConnectMediaDataSource dataSource() => AgriConnectMediaDataSource(
      SupabaseClient('http://127.0.0.1:${server.port}', 'local-test-jwt'),
    );

    test(
      'uploadPostImage sends context=agri_connect_post + context_id=post id',
      () async {
        final payload = await dataSource().uploadPostImage(
          bytes: _imageBytes(),
          fileName: 'probe.webp',
          postId: _postId,
        );

        expect(payload, isA<Map>());
        expect(captures, hasLength(1));
        final capture = captures.single;
        expect(capture, startsWith('POST /functions/v1/upload_media'));
        expect(
          capture,
          contains('name="context"\r\n\r\nagri_connect_post'),
          reason: 'comment uploads use the single shared post context',
        );
        expect(
          capture,
          contains('name="context_id"\r\n\r\n$_postId'),
          reason: 'the uploader keys the reservation to the created post',
        );
        expect(
          capture,
          isNot(contains('name="context"\r\n\r\ndiscussions')),
          reason: 'the discussions context must never be sent for posts',
        );
        expect(
          capture,
          isNot(contains('agri_connect_discussion')),
          reason: 'the lookup alias must never be sent to upload_media',
        );
        expect(capture, contains('name="file"'));
      },
    );

    test('uploadPostImage rejects a success:false payload', () async {
      uploadBody = const {
        'success': false,
        'error': 'post image limit reached',
      };
      await expectLater(
        dataSource().uploadPostImage(
          bytes: _imageBytes(),
          fileName: 'probe.webp',
          postId: _postId,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(
              contains('Upload failed'),
              contains('post image limit reached'),
            ),
          ),
        ),
      );
    });

    test('uploadPostImage rejects a malformed (non-Map) payload', () async {
      uploadBody = 'ok';
      await expectLater(
        dataSource().uploadPostImage(
          bytes: _imageBytes(),
          fileName: 'probe.webp',
          postId: _postId,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Unexpected response from the server.'),
          ),
        ),
      );
    });

    test('uploadPostImage surfaces an HTTP failure as Upload failed', () async {
      uploadStatusCode = 500;
      uploadBody = const {'message': 'storage unavailable'};
      await expectLater(
        dataSource().uploadPostImage(
          bytes: _imageBytes(),
          fileName: 'probe.webp',
          postId: _postId,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Upload failed'),
          ),
        ),
      );
    });

    test(
      'fetchMediaEntries sends agri_connect_post to media_get_by_context',
      () async {
        await dataSource().fetchMediaEntries(
          context: AgriConnectMediaDataSource.postContext,
          contextId: _postId,
        );

        expect(captures, hasLength(1));
        final capture = captures.single;
        expect(capture, startsWith('POST /functions/v1/media_get_by_context'));
        expect(capture, contains('"context":"agri_connect_post"'));
        expect(capture, contains('"context_id":"$_postId"'));
        expect(
          capture,
          isNot(contains('"context":"discussions"')),
          reason: 'posts never fall back to the discussions context',
        );
      },
    );

    test('fetchMediaEntries surfaces an HTTP failure', () async {
      lookupStatusCode = 500;
      lookupBody = const {'message': 'lookup down'};
      await expectLater(
        dataSource().fetchMediaEntries(
          context: AgriConnectMediaDataSource.postContext,
          contextId: _postId,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to load media'),
          ),
        ),
      );
    });

    test(
      'removePostMedia calls the agri_connect RPC with both arguments',
      () async {
        await dataSource().removePostMedia(postId: _postId, fileId: _fileId);

        expect(captures, hasLength(1));
        final capture = captures.single;
        expect(
          capture,
          startsWith('POST /rest/v1/rpc/remove_post_media'),
          reason:
              'removal must go through the database RPC, not an edge '
              'function',
        );
        expect(capture, contains('"p_post_id":"$_postId"'));
        expect(capture, contains('"p_file_id":"$_fileId"'));
        expect(
          capture,
          isNot(contains('/functions/v1/delete_media')),
          reason:
              'the listing-specific delete_media edge function must never '
              'be used for comment images',
        );
        expect(
          capture,
          isNot(contains('/rpc/delete_discussion_media')),
          reason: 'discussion removal must not run for post images',
        );
      },
    );

    test(
      'removePostMedia accepts a storage_retained success payload',
      () async {
        rpcBody = const {'storage_retained': true, 'file_id': _fileId};
        await expectLater(
          dataSource().removePostMedia(postId: _postId, fileId: _fileId),
          completes,
        );
      },
    );

    test(
      'removePostMedia surfaces the database error details on failure',
      () async {
        rpcStatusCode = 400;
        rpcBody = const {
          'code': 'P0001',
          'message': 'post image not found',
          'details': null,
          'hint': null,
        };
        await expectLater(
          dataSource().removePostMedia(postId: _postId, fileId: _fileId),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              allOf(
                contains('Image removal failed'),
                contains('post image not found'),
              ),
            ),
          ),
        );
      },
    );

    test('removePostMedia rejects a success:false payload', () async {
      rpcBody = const {'success': false, 'error': 'not authorized'};
      await expectLater(
        dataSource().removePostMedia(postId: _postId, fileId: _fileId),
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
