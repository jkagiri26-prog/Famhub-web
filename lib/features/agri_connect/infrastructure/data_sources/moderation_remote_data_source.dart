/// ============================================================
/// AGRI CONNECT — MODERATION REMOTE DATA SOURCE
/// ============================================================
///
/// Raw Supabase operations for reports, blocks and moderation actions.
/// Report identity is immutable; only moderation fields are updatable.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class ModerationRemoteDataSource {
  final SupabaseClient _client;

  ModerationRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String _schema = 'agri_connect';

  static const String _reportSelect = '''
    id, reporter_profile_id, target_type, target_id, reason, description,
    status, reviewed_by, reviewed_at, resolution, created_at
  ''';

  // ── Reports ────────────────────────────────────────────────

  Future<Map<String, dynamic>> insertReport(Map<String, dynamic> data) async {
    try {
      return await _client
          .schema(_schema)
          .from('content_reports')
          .insert(data)
          .select(_reportSelect)
          .single();
    } on PostgrestException catch (e) {
      throw Exception('Failed to submit report: ${e.message}');
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  /// Pending reports the caller is authorized to review (RLS-scoped).
  ///
  /// `content_reports` has no community_id column; which reports a given
  /// reviewer may see is enforced entirely by RLS server-side.
  Future<List<Map<String, dynamic>>> fetchReports() async {
    try {
      final response = await _client
          .schema(_schema)
          .from('content_reports')
          .select(_reportSelect)
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      return (response as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load reports: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load reports: $e');
    }
  }

  Future<void> reviewReport({
    required String reportId,
    required String status,
    String? resolution,
  }) async {
    try {
      await _client
          .schema(_schema)
          .from('content_reports')
          .update({
            'status': status,
            'reviewed_at': DateTime.now().toIso8601String(),
            if (resolution != null) 'resolution': resolution,
          })
          .eq('id', reportId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to review report: ${e.message}');
    } catch (e) {
      throw Exception('Failed to review report: $e');
    }
  }

  // ── Blocks ─────────────────────────────────────────────────

  Future<void> insertBlock({
    required String blockerProfileId,
    required String blockedProfileId,
  }) async {
    try {
      await _client.schema(_schema).from('user_blocks').insert({
        'blocker_profile_id': blockerProfileId,
        'blocked_profile_id': blockedProfileId,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to block user: ${e.message}');
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  Future<void> deleteBlock({
    required String blockerProfileId,
    required String blockedProfileId,
  }) async {
    try {
      await _client
          .schema(_schema)
          .from('user_blocks')
          .delete()
          .eq('blocker_profile_id', blockerProfileId)
          .eq('blocked_profile_id', blockedProfileId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to unblock user: ${e.message}');
    } catch (e) {
      throw Exception('Failed to unblock user: $e');
    }
  }

  Future<List<String>> fetchBlockedProfileIds(String blockerProfileId) async {
    try {
      final response = await _client
          .schema(_schema)
          .from('user_blocks')
          .select('blocked_profile_id')
          .eq('blocker_profile_id', blockerProfileId);
      return (response as List)
          .map((r) => (r as Map)['blocked_profile_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load blocked users: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load blocked users: $e');
    }
  }

  // ── Moderation actions ─────────────────────────────────────

  Future<Map<String, dynamic>> insertModerationAction(
    Map<String, dynamic> data,
  ) async {
    try {
      return await _client
          .schema(_schema)
          .from('moderation_actions')
          .insert(data)
          .select()
          .single();
    } on PostgrestException catch (e) {
      throw Exception('Failed to apply moderation action: ${e.message}');
    } catch (e) {
      throw Exception('Failed to apply moderation action: $e');
    }
  }
}
