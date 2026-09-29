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
/// ============================================================
library;

import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AgriConnectMediaDataSource {
  final SupabaseClient _client;

  AgriConnectMediaDataSource(this._client);

  static const String communitiesContext = 'communities';
  static const String messagesContext = 'messages';

  static const String _uploadFn = 'upload_media';
  static const String _getByContextFn = 'media_get_by_context';
  static const String _deleteFn = 'delete_media';

  /// Upload an image for a community's profile image.
  Future<void> uploadCommunityImage({
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

  /// Upload a message media attachment.
  Future<void> uploadMessageMedia({
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
      return _entries(response.data);
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

  Future<void> _upload({
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

  static List<Map<String, String>> _entries(dynamic payload) {
    final List<dynamic> raw;
    if (payload is List) {
      raw = payload;
    } else if (payload is Map) {
      final inner = payload['data'] ?? payload['media'] ?? payload['files'];
      raw = inner is List ? inner : const [];
    } else {
      raw = const [];
    }

    final entries = <Map<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final url = (item['url'] ?? item['signed_url'] ?? item['public_url'])
          ?.toString();
      final lower = url?.toLowerCase() ?? '';
      if (lower.isEmpty ||
          (!lower.startsWith('http://') && !lower.startsWith('https://'))) {
        continue;
      }
      final id = (item['id'] ?? item['file_id'] ?? item['media_id'])
          ?.toString();
      entries.add({'url': url!, if (id != null && id.isNotEmpty) 'id': id});
    }
    return entries;
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
