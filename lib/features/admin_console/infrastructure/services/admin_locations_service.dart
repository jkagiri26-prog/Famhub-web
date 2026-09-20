import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_location.dart';

/// ============================================================
/// ADMIN LOCATIONS SERVICE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/infrastructure/services/ = infrastructure
///
/// The ONLY frontend entry point for canonical `core.locations` admin
/// management. Uses the deployed admin RPCs (authorized server-side):
///   users.admin_list_locations
///   users.admin_create_location
///   users.admin_update_location
///   users.admin_set_location_active
///
/// ❌ Never queries `core.locations` directly and adds no client-side
///    authorization logic. The backend remains authoritative.
/// ============================================================
class AdminLocationsService {
  final _client = SupabaseService.instance.client;

  Future<AdminLocationsPage> listLocations({
    String? parentId,
    String? levelId,
    String? countryId,
    String? search,
    bool? isActive,
    int limit = 25,
    int offset = 0,
    String sort = 'name',
    String order = 'asc',
  }) async {
    try {
      final response = await _client.schema('users').rpc(
        'admin_list_locations',
        params: {
          'p_parent_id': parentId,
          'p_level_id': levelId,
          'p_country_id': countryId,
          'p_search': search,
          'p_is_active': isActive,
          'p_limit': limit,
          'p_offset': offset,
          'p_sort': sort,
          'p_order': order,
        },
      );

      final rows = (response as List)
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

      final totalCount = rows.isEmpty
          ? 0
          : (rows.first['total_count'] as num?)?.toInt() ?? rows.length;

      return AdminLocationsPage(
        items: rows.map(AdminLocation.fromMap).toList(),
        totalCount: totalCount,
      );
    } on PostgrestException catch (e) {
      throw AdminLocationsException(e.message);
    } catch (e) {
      throw AdminLocationsException('$e');
    }
  }

  Future<void> createLocation({
    required String name,
    required String levelId,
    required String countryId,
    String? parentId,
    int? code,
  }) async {
    try {
      await _client.schema('users').rpc('admin_create_location', params: {
        'p_name': name,
        'p_level_id': levelId,
        'p_country_id': countryId,
        'p_parent_id': parentId,
        'p_code': code,
      });
    } on PostgrestException catch (e) {
      throw AdminLocationsException(e.message);
    } catch (e) {
      throw AdminLocationsException('$e');
    }
  }

  Future<void> updateLocation({
    required String locationId,
    required String name,
    required String levelId,
    required String? parentId,
    required String countryId,
    required int? code,
  }) async {
    try {
      await _client.schema('users').rpc('admin_update_location', params: {
        'p_location_id': locationId,
        'p_name': name,
        'p_level_id': levelId,
        'p_parent_id': parentId,
        'p_country_id': countryId,
        'p_code': code,
      });
    } on PostgrestException catch (e) {
      throw AdminLocationsException(e.message);
    } catch (e) {
      throw AdminLocationsException('$e');
    }
  }

  Future<void> setLocationActive({
    required String locationId,
    required bool isActive,
  }) async {
    try {
      await _client.schema('users').rpc('admin_set_location_active', params: {
        'p_location_id': locationId,
        'p_is_active': isActive,
      });
    } on PostgrestException catch (e) {
      throw AdminLocationsException(e.message);
    } catch (e) {
      throw AdminLocationsException('$e');
    }
  }
}

class AdminLocationsException implements Exception {
  final String message;

  AdminLocationsException(this.message);

  @override
  String toString() => message;
}
