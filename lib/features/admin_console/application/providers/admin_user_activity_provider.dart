/// ============================================================
/// ADMIN USER ACTIVITY PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/application/providers/ = application layer
///
/// Bridges the user activity UI to the admin-safe read service
/// (`AdminUserActivityService` → `users.admin_list_user_activity`).
///
/// The query is immutable + equatable so Riverpod caches each
/// (search, event type, date range, page) combination.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/admin_console/domain/models/admin_user_activity.dart';
import 'package:famhub_app/features/admin_console/infrastructure/services/admin_user_activity_service.dart';

final adminUserActivityServiceProvider =
    Provider<AdminUserActivityService>((ref) => AdminUserActivityService());

class AdminUserActivityQuery {
  final String? search;
  final String? eventType;
  final DateTime? startDate;
  final DateTime? endDate;
  final int page;
  final int pageSize;

  const AdminUserActivityQuery({
    this.search,
    this.eventType,
    this.startDate,
    this.endDate,
    this.page = 0,
    this.pageSize = 25,
  });

  int get offset => page * pageSize;

  @override
  bool operator ==(Object other) =>
      other is AdminUserActivityQuery &&
      other.search == search &&
      other.eventType == eventType &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode =>
      Object.hash(search, eventType, startDate, endDate, page, pageSize);
}

final adminUserActivityProvider =
    FutureProvider.family<AdminUserActivityPage, AdminUserActivityQuery>(
  (ref, query) async {
    final service = ref.watch(adminUserActivityServiceProvider);
    final search = query.search?.trim();
    return service.listActivity(
      limit: query.pageSize,
      offset: query.offset,
      search: (search == null || search.isEmpty) ? null : search,
      eventType: query.eventType,
      startAt: _inclusiveStart(query.startDate),
      endAt: _exclusiveEnd(query.endDate),
      sort: 'occurred_at',
      order: 'desc',
    );
  },
);

/// Inclusive lower bound: local start-of-day of the selected date.
String? _inclusiveStart(DateTime? date) {
  if (date == null) return null;
  return DateTime(date.year, date.month, date.day).toIso8601String();
}

/// Exclusive upper bound: local start-of-day of the day AFTER the selected
/// date, so the whole selected calendar day is included.
String? _exclusiveEnd(DateTime? date) {
  if (date == null) return null;
  final next = DateTime(date.year, date.month, date.day)
      .add(const Duration(days: 1));
  return next.toIso8601String();
}
