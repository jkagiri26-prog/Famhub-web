import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_user.dart';

/// ============================================================
/// ADMIN USERS SERVICE (READ-ONLY)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/infrastructure/services/ = infrastructure
///
/// The ONLY frontend entry point for the platform-wide admin user
/// directory. It calls the admin-safe RPC `users.admin_list_users`, which is
/// SECURITY DEFINER and authorizes the caller server-side through
/// `core.has_permission('admin.users.view')`.
///
/// ❌ Never queries `auth.users`, `users.profiles`, `users.otp` or
///    `core.entity_members` directly.
/// ============================================================
class AdminUsersService {
  final _client = SupabaseService.instance.client;

  Future<AdminUsersPage> listUsers({
    int limit = 25,
    int offset = 0,
    String? search,
    String? status,
    String? userType,
    String sort = 'created_at',
    String order = 'desc',
  }) async {
    try {
      final response = await _client.schema('users').rpc(
        'admin_list_users',
        params: {
          'p_limit': limit,
          'p_offset': offset,
          'p_search': search,
          'p_status': status,
          'p_user_type': userType,
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

      return AdminUsersPage(
        items: rows.map(AdminUser.fromMap).toList(),
        totalCount: totalCount,
      );
    } on PostgrestException catch (e) {
      throw AdminUsersException('Failed to load users: ${e.message}');
    } catch (e) {
      throw AdminUsersException('Failed to load users: $e');
    }
  }
}

class AdminUsersException implements Exception {
  final String message;

  AdminUsersException(this.message);

  @override
  String toString() => 'AdminUsersException: $message';
}
