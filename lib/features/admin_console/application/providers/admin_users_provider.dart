/// ============================================================
/// ADMIN USERS PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/application/providers/ = application layer
///
/// Bridges the admin user directory UI to the admin-safe read service
/// (`AdminUsersService` → `users.admin_list_users`).
///
/// The query is an immutable, equatable value so Riverpod caches each
/// (search, status, page) combination and refetches only when it changes.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/domain/models/admin_user.dart';
import 'package:famhub_app/features/admin_console/infrastructure/services/admin_users_service.dart';

final adminUsersServiceProvider =
    Provider<AdminUsersService>((ref) => AdminUsersService());

class AdminUsersQuery {
  final String? search;
  final String? status;
  final int page;
  final int pageSize;

  const AdminUsersQuery({
    this.search,
    this.status,
    this.page = 0,
    this.pageSize = 25,
  });

  int get offset => page * pageSize;

  AdminUsersQuery copyWith({
    String? search,
    String? status,
    int? page,
    int? pageSize,
  }) {
    return AdminUsersQuery(
      search: search ?? this.search,
      status: status ?? this.status,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdminUsersQuery &&
      other.search == search &&
      other.status == status &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(search, status, page, pageSize);
}

final adminUsersProvider =
    FutureProvider.family<AdminUsersPage, AdminUsersQuery>((ref, query) async {
  final service = ref.watch(adminUsersServiceProvider);
  final search = query.search?.trim();
  return service.listUsers(
    limit: query.pageSize,
    offset: query.offset,
    search: (search == null || search.isEmpty) ? null : search,
    status: query.status,
    // `user_type` is not deployed — always null.
    userType: null,
    sort: 'created_at',
    order: 'desc',
  );
});
