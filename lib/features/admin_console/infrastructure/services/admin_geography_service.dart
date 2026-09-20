import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/features/admin_console/domain/models/admin_location.dart';
import 'package:famhub_app/features/admin_console/infrastructure/services/admin_locations_service.dart';

/// ============================================================
/// ADMIN GEOGRAPHY SERVICE (READ-ONLY REFERENCE DATA)
/// ============================================================
///
/// Canonical country / geography-level reference data needed by the admin
/// location filters and forms. Mirrors the existing approved frontend read
/// pattern (`profile_location_provider` reads the same tables); it is NOT a
/// new taxonomy and never touches `core.locations`.
/// ============================================================
class AdminGeographyService {
  final _client = SupabaseService.instance.client;

  Future<List<AdminCountry>> listCountries() async {
    try {
      final response = await _client
          .schema('core')
          .from('countries')
          .select('id, name, iso_alpha2')
          .order('name');
      return (response as List)
          .whereType<Map>()
          .map((r) => AdminCountry.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminLocationsException(e.message);
    } catch (e) {
      throw AdminLocationsException('$e');
    }
  }

  Future<List<AdminGeographyLevel>> listGeographyLevels({
    String? countryId,
  }) async {
    try {
      final base = _client
          .schema('core')
          .from('geography_levels')
          .select('id, level_name, level_order, country_id');
      final filtered = (countryId == null || countryId.isEmpty)
          ? base
          : base.eq('country_id', countryId);
      final response = await filtered.order('level_order', ascending: true);
      return (response as List)
          .whereType<Map>()
          .map((r) => AdminGeographyLevel.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminLocationsException(e.message);
    } catch (e) {
      throw AdminLocationsException('$e');
    }
  }
}
