/// ============================================================
/// AGRI CONNECT — MEDIA DATA SOURCE
/// ============================================================
///
/// Reuses the existing FAMHUB media architecture via the deployed
/// edge functions (`upload_media`, `media_get_by_context`, `delete_media`).
/// The client never writes to Storage or `media.context_access`.
///
/// Context contract (matches the deployed backend):
///   community profile image → context "communities", context_id = community id
///   message attachment       → context "messages",    context_id = message id
///   discussion image UPLOAD  → context "discussions" — the established
///                              `upload_media` value; any other value is
///                              rejected by that function
///   discussion image LOOKUP  → context "agri_connect_discussion" — the
///                              alias `media_get_by_context` accepts
///                              (alongside "discussion_posts"/"posts")
///                              for listing a discussion's media
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

  /// Established context value for `upload_media` on discussion images.
  /// The deployed upload function only accepts this original value — it
  /// must never be changed to an alias ("agri_connect_discussion",
  /// "discussion"), or the upload is rejected and the media phase fails.
  static const String discussionsContext = 'discussions';

  /// Context value `media_get_by_context` accepts when listing a
  /// discussion's media (the alias fixed in the deployed backend that
  /// makes image display work). Lookups use this; uploads do not.
  static const String discussionLookupContext = 'agri_connect_discussion';

  /// Single context shared by upload and lookup for comment/reply images:
  /// `upload_media` (v31+) reserves the post's image slot and registers
  /// the attachment itself with `context_id = posts.id`, and
  /// `media_get_by_context` resolves the same value for display. A post
  /// supports up to 2 images (backend-enforced).
  static const String postContext = 'agri_connect_post';

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

  /// Upload one comment/reply image for an already-created post. The
  /// uploader reserves the post's image slot and registers the attachment
  /// itself — the client never writes post media state, so this method
  /// only reports the upload's outcome. Transport errors, HTTP errors,
  /// `success: false` and malformed payloads all surface as exceptions
  /// (see [_upload] / [_failureReason]); nothing is treated as saved
  /// unless the backend confirmed it.
  Future<dynamic> uploadPostImage({
    required Uint8List bytes,
    required String fileName,
    required String postId,
  }) {
    return _upload(
      context: postContext,
      contextId: postId,
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

  /// Generic `delete_media` edge function (listing-specific contract).
  /// Never use this for Agri Connect discussion images — use
  /// [deleteDiscussionMedia] instead.
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

  /// Schema holding the Agri Connect media RPCs (`delete_discussion_media`,
  /// `remove_post_media`).
  static const String _agriSchema = 'agri_connect';

  /// Remove a discussion image through the existing authorized RPC
  /// `agri_connect.delete_discussion_media(p_file_id)` — the only
  /// supported removal path for discussion media (the generic
  /// `delete_media` edge function is listing-specific).
  ///
  /// The RPC detaches the id from `metadata.media_file_ids`, marks the
  /// media record deleted and records the deletion event, returning
  /// `storage_retained: true` — the Storage object stays, and the client
  /// never deletes Storage objects directly.
  ///
  /// Failures surface the backend's own error text; nothing about the
  /// removal is reported as successful unless the RPC completed.
  Future<void> deleteDiscussionMedia(String fileId) async {
    final Object? data;
    try {
      data = await _client
          .schema(_agriSchema)
          .rpc('delete_discussion_media', params: {'p_file_id': fileId});
    } on PostgrestException catch (e) {
      // Diagnostic: surface the database's own error (rule violation,
      // authorization, missing row) for device logs.
      // ignore: avoid_print
      print(
        '[delete_discussion_media] code=${e.code} message=${e.message} '
        'details=${e.details}',
      );
      throw Exception('Media removal failed: ${e.message}');
    } catch (e) {
      throw Exception('Media removal failed: $e');
    }
    final reason = _rpcRemovalFailureReason(data);
    if (reason != null) {
      throw Exception('Media removal failed: $reason');
    }
  }

  /// Remove a comment/reply image through the authorized RPC
  /// `agri_connect.remove_post_media(p_post_id, p_file_id)` — the only
  /// supported removal path for post media (never the listing-only
  /// `delete_media` edge function, never a direct Storage delete).
  ///
  /// Failures surface the backend's own error text; nothing about the
  /// removal is reported as successful unless the RPC completed.
  Future<void> removePostMedia({
    required String postId,
    required String fileId,
  }) async {
    final Object? data;
    try {
      data = await _client
          .schema(_agriSchema)
          .rpc(
            'remove_post_media',
            params: {'p_post_id': postId, 'p_file_id': fileId},
          );
    } on PostgrestException catch (e) {
      // Diagnostic: surface the database's own error (rule violation,
      // authorization, missing row) for device logs.
      // ignore: avoid_print
      print(
        '[remove_post_media] code=${e.code} message=${e.message} '
        'details=${e.details}',
      );
      throw Exception('Image removal failed: ${e.message}');
    } catch (e) {
      throw Exception('Image removal failed: $e');
    }
    final reason = _rpcRemovalFailureReason(data);
    if (reason != null) {
      throw Exception('Image removal failed: $reason');
    }
  }

  /// Detect an error payload returned by `delete_discussion_media`
  /// instead of a raised database error. A payload without an error
  /// marker (e.g. `{storage_retained: true}`) is a success.
  static String? _rpcRemovalFailureReason(Object? payload) {
    if (payload is Map) {
      if (payload['success'] == false) {
        return payload['error']?.toString().isNotEmpty == true
            ? payload['error'].toString()
            : payload['message']?.toString() ??
                  'The server rejected the removal.';
      }
      final error = payload['error'];
      if (error is String && error.isNotEmpty) return error;
    }
    return null;
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
