import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/module_zone_mapping.dart';

class ModuleZoneMappingRepository {
  ModuleZoneMappingRepository(this.client);

  final SupabaseClient client;

  Future<List<ModuleZoneMapping>> fetchMappings() async {
    final response = await client
        .from('system.module_zone_mappings')
        .select();

    return (response as List)
        .map(
          (e) => ModuleZoneMapping(
            moduleKey: e['module_key'],
            zoneId: e['zone_id'],
          ),
        )
        .toList();
  }
}