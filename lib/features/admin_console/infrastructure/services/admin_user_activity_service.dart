import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_user_activity.dart';

/// ============================================================
/// ADMIN USER ACTIVITY SERVICE (READ-ONLY)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/infrastructure/services/ = infrastructure
///
/// The ONLY frontend entry point for the admin user activity feed. It calls
/// the admin-safe RPC `users.admin_list_user_activity` (SECURITY DEFINER,
/// authorized server-side via `core.has_permission('admin.users.view')`).
///
/// ❌ Never queries `auth.audit_log_entries`, `auth.users` or `users.profiles`
///    directly, and never exposes raw audit payloads.
/// ============================================================
class AdminUserActivityService {
  final _client = SupabaseService.instance.client;

  Future<AdminUserActivityPage> listActivity({
    int limit = 25,
    int offset = 0,
    String? profileId,
    String? search,
    String? eventType,
    String? startAt,
    String? endAt,
    String sort = 'occurred_at',
    String order = 'desc',
  }) async {
    try {
      final response = await _client.schema('users').rpc(
        'admin_list_user_activity',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_profile_id': profileId,
          'p_search': search,
          'p_event_type': eventType,
          'p_start_at': startAt,
          'p_end_at': endAt,
          'p_sort': sort,
          'p_order': order,
        },
      );

      final rows = (response as List)
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

      // `total_count` is returned on each row (0 rows → empty result).
      final totalCount = rows.isEmpty
          ? 0
          : (rows.first['total_count'] as num?)?.toInt() ?? rows.length;

      return AdminUserActivityPage(
        items: rows.map(AdminUserActivity.fromMap).toList(),
        totalCount: totalCount,
      );
    } on PostgrestException catch (e) {
      throw AdminUserActivityException(
        'Failed to load user activity: ${e.message}',
      );
    } catch (e) {
      throw AdminUserActivityException('Failed to load user activity: $e');
    }
  }
}

class AdminUserActivityException implements Exception {
  final String message;

  AdminUserActivityException(this.message);

  @override
  String toString() => 'AdminUserActivityException: $message';
}
