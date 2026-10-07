/// ============================================================
/// AGRI CONNECT — MEDIA DATA SOURCE
/// ============================================================
///
/// Reuses the existing FAMHUB media architecture via the deployed
/// edge functions (`upload_media`, `media_get_by_context`, `delete_media`).
/// The client never writes to Storage or `media.context_access`.
///
/// Context contract (adjust to the deployed backend if it differs):
///   community profile image → context "communities", context_id = community id
///   message attachment       → context "messages",    context_id = message id
///   discussion image         → context "discussions", context_id = discussion id
/// ============================================================
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgriConnectMediaDataSource {
  final SupabaseClient _client;

  AgriConnectMediaDataSource(this._client);

  static const String communitiesContext = 'communities';
  static const String messagesContext = 'messages';
  static const String discussionsContext = 'discussions';

  static const String _uploadFn = 'upload_media';
  static const String _getByContextFn = 'media_get_by_context';
  static const String _deleteFn = 'delete_media';

  /// Private bucket holding all media files — never read with
  /// `getPublicUrl`; only short-lived signed URLs are used.
  static const String mediaBucket = 'media';

  /// Lifetime of client-signed URLs. Expired URLs are re-signed on the next
  /// provider refresh or an image retry (the provider is re-evaluated and
  /// [resolveDisplayUrl] signs again).
  static const int signedUrlTtlSeconds = 3600;

  /// Upload an image for a community's profile image. Returns the raw
  /// function payload so callers can read file ids/paths when present.
  Future<dynamic> uploadCommunityImage({
    required Uint8List bytes,
    required String fileName,
    required String communityId,
  }) {
    return _upload(
      context: communitiesContext,
      contextId: communityId,
      bytes: bytes,
      fileName: fileName,
      contentType: MediaType('image', 'webp'),
    );
  }

  /// Upload an image attachment for a discussion (max 2 per discussion,
  /// enforced by the calling feature code). Returns the raw function
  /// payload — parsed for the new `media.files` id when the response
  /// carries one, so linking does not depend on a second round-trip.
  Future<dynamic> uploadDiscussionImage({
    required Uint8List bytes,
    required String fileName,
    required String discussionId,
  }) {
    return _upload(
      context: discussionsContext,
      contextId: discussionId,
      bytes: bytes,
      fileName: fileName,
      contentType: MediaType('image', 'webp'),
    );
  }

  /// Upload a message media attachment.
  Future<dynamic> uploadMessageMedia({
    required Uint8List bytes,
    required String fileName,
    required String messageId,
    required String contentType,
  }) {
    return _upload(
      context: messagesContext,
      contextId: messageId,
      bytes: bytes,
      fileName: fileName,
      contentType: MediaType.parse(contentType),
    );
  }

  /// Resolve signed URLs for a context (community profile image / message).
  Future<List<String>> fetchMediaUrls({
    required String context,
    required String contextId,
  }) async {
    final entries = await fetchMediaEntries(
      context: context,
      contextId: contextId,
    );
    return [
      for (final e in entries)
        if (e['url'] != null) e['url']!,
    ];
  }

  Future<List<Map<String, String>>> fetchMediaEntries({
    required String context,
    required String contextId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        _getByContextFn,
        body: {'context': context, 'context_id': contextId},
      );
      final entries = parseMediaEntries(response.data);
      if (entries.isEmpty) {
        final items = collectMediaItems(response.data);
        if (items.isNotEmpty) {
          // The function returned items but none were parseable — surface
          // the raw shape instead of failing silently, so the UI can show
          // exactly what came back.
          final sample = jsonEncode(items.first).toString();
          throw Exception(
            'Unrecognized media response (${items.length} item(s)): '
            '${sample.length > 400 ? sample.substring(0, 400) : sample}',
          );
        }
      }
      return entries;
    } on FunctionException catch (e) {
      throw Exception(_describeFunctionError('Failed to load media', e));
    }
  }

  Future<void> deleteMedia(String fileId) async {
    try {
      final response = await _client.functions.invoke(
        _deleteFn,
        body: {'file_id': fileId},
      );
      final reason = _failureReason(response.data);
      if (reason != null) {
        throw Exception('Media removal failed: $reason');
      }
    } on FunctionException catch (e) {
      throw Exception(_describeFunctionError('Media removal failed', e));
    }
  }

  Future<dynamic> _upload({
    required String context,
    required String contextId,
    required Uint8List bytes,
    required String fileName,
    required MediaType contentType,
  }) async {
    try {
      final response = await _client.functions.invoke(
        _uploadFn,
        body: {'context': context, 'context_id': contextId},
        files: [
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
            contentType: contentType,
          ),
        ],
      );
      final reason = _failureReason(response.data);
      if (reason != null) {
        throw Exception('Upload failed: $reason');
      }
      return response.data;
    } on FunctionException catch (e) {
      throw Exception(_describeFunctionError('Upload failed', e));
    }
  }

  static String? _failureReason(dynamic payload) {
    if (payload is Map) {
      if (payload['success'] == true) return null;
      return payload['error']?.toString() ??
          payload['message']?.toString() ??
          'The server rejected the request.';
    }
    if (payload == null) return 'No response from the server.';
    return 'Unexpected response from the server.';
  }

  /// Locate the list of media items inside any payload shape the deployed
  /// media functions return: a bare list, `{data|files|media|items|...}`
  /// (flat or one level nested), or a single media-object map.
  /// Public so the parsing contract is unit-testable.
  static List<dynamic> collectMediaItems(dynamic payload) {
    const keys = [
      'data',
      'files',
      'media',
      'items',
      'results',
      'entries',
      'file',
    ];
    if (payload is List) return payload;
    if (payload is Map) {
      for (final key in keys) {
        final value = payload[key];
        if (value == null) continue;
        if (value is List) return value;
        if (value is Map) {
          final nested = collectMediaItems(value);
          if (nested.isNotEmpty) return nested;
        }
      }
      // Single-object payload that looks like one media item.
      if (payload.containsKey('id') ||
          payload.containsKey('file_id') ||
          payload.containsKey('media_id') ||
          payload.containsKey('path') ||
          payload.containsKey('url')) {
        return [payload];
      }
    }
    return const [];
  }

  /// Normalize media items to `{url?, path?, id?}` maps. Entries that only
  /// carry a storage path are kept (they are signed client-side by
  /// [resolveDisplayUrl]); an `id`-only entry is kept for linking.
  /// Public so the parsing contract is unit-testable.
  static List<Map<String, String>> parseMediaEntries(dynamic payload) {
    final raw = collectMediaItems(payload);

    final entries = <Map<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final rawUrl =
          (item['url'] ??
                  item['signed_url'] ??
                  item['signedUrl'] ??
                  item['public_url'])
              ?.toString();
      final lower = rawUrl?.toLowerCase() ?? '';
      final isHttp =
          lower.startsWith('http://') || lower.startsWith('https://');

      // Storage path: an explicit path key, or a non-http `url` value —
      // the media functions may return the raw object path instead of a
      // pre-signed URL. Never drop entries that only carry a path: they
      // are signed client-side by [resolveDisplayUrl].
      var path = (item['path'] ?? item['storage_path'] ?? item['object_path'])
          ?.toString();
      if ((path == null || path.isEmpty) && rawUrl != null && !isHttp) {
        path = rawUrl;
      }

      final id = (item['id'] ?? item['file_id'] ?? item['media_id'])
          ?.toString();
      if (!isHttp &&
          (path == null || path.isEmpty) &&
          (id == null || id.isEmpty)) {
        continue; // Nothing usable in this entry.
      }
      entries.add({
        if (isHttp) 'url': rawUrl!,
        if (path != null && path.isNotEmpty) 'path': path,
        if (id != null && id.isNotEmpty) 'id': id,
      });
    }
    return entries;
  }

  /// Return a displayable, short-lived **signed URL** for a media entry.
  ///
  /// 1. Uses the URL returned by the media edge function when present.
  /// 2. Otherwise signs [entry]'s storage path directly against the private
  ///    `media` bucket with `createSignedUrl` (authenticated, RLS-checked —
  ///    the bucket stays private).
  ///
  /// Never returns a `getPublicUrl` URL or a raw storage path — callers may
  /// only pass the result to an image widget. Throws with the underlying
  /// status on failure so storage access problems are diagnosable.
  Future<String> resolveDisplayUrl(Map<String, String> entry) async {
    final url = entry['url'];
    if (url != null && url.isNotEmpty) {
      final lower = url.toLowerCase();
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        return url;
      }
    }
    final path = entry['path'];
    if (path == null || path.isEmpty) {
      throw Exception('The image has no storage path or signed URL.');
    }
    try {
      final signed = await _client.storage
          .from(mediaBucket)
          .createSignedUrl(path, signedUrlTtlSeconds);
      final lower = signed.toLowerCase();
      if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
        throw Exception('The server returned an unusable URL for $path.');
      }
      return signed;
    } on StorageException catch (e) {
      throw Exception(
        'Could not sign image URL (${e.statusCode ?? 'error'}): '
        '${e.message} [$path]',
      );
    }
  }

  static String _describeFunctionError(String action, FunctionException e) {
    if (e.status == 401) {
      return '$action: your session has expired. Sign in and try again.';
    }
    if (e.status == 403) {
      return '$action: you do not have permission to do this.';
    }
    final details = e.details?.toString();
    if (details != null && details.isNotEmpty) return '$action: $details';
    return '$action: please try again.';
  }
}
