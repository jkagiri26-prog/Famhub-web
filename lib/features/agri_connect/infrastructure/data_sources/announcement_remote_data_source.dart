/// ============================================================
/// AGRI CONNECT — ANNOUNCEMENT REMOTE DATA SOURCE
/// ============================================================
///
/// Raw Supabase operations for `agri_connect.announcements`.
/// Reads are RLS-scoped (published/unexpired + community/entity auth).
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementRemoteDataSource {
  final SupabaseClient _client;

  AnnouncementRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _schema = 'agri_connect';

  static const String _select = '''
    id, title, body, announcement_type, community_id, entity_id, published_by,
    is_published, published_at, expires_at, is_pinned, metadata, created_at,
    updated_at
  ''';

  Future<List<Map<String, dynamic>>> fetchAnnouncements({
    String? communityId,
    String? type,
  }) async {
    try {
      var query = _client
          .schema(_schema)
          .from('announcements')
          .select(_select)
          .eq('is_published', true);

      if (communityId != null && communityId.isNotEmpty) {
        query = query.eq('community_id', communityId);
      }
      if (type != null && type.isNotEmpty) {
        query = query.eq('announcement_type', type);
      }

      final response = await query
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load announcements: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load announcements: $e');
    }
  }

  Future<Map<String, dynamic>> insertAnnouncement(
    Map<String, dynamic> data,
  ) async {
    try {
      return await _client
          .schema(_schema)
          .from('announcements')
          .insert(data)
          .select(_select)
          .single();
    } on PostgrestException catch (e) {
      throw Exception('Failed to create announcement: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create announcement: $e');
    }
  }

  Future<void> updateAnnouncement(String id, Map<String, dynamic> data) async {
    try {
      await _client
          .schema(_schema)
          .from('announcements')
          .update(data)
          .eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update announcement: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update announcement: $e');
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    try {
      await _client.schema(_schema).from('announcements').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete announcement: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete announcement: $e');
    }
  }
}
