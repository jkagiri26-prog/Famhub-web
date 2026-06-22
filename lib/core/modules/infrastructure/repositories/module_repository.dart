import '../../domain/models/system_module.dart';
import 'package:famhub_app/core/services/supabase_service.dart';

class ModuleRepository {
  Future<List<SystemModule>> fetchEnabledModules() async {
    try {
      final response = await SupabaseService.instance.client
          .rpc('get_enabled_modules');
      
      if (response == null) return [];

      final List<dynamic> data = response as List<dynamic>;
      return data.map((m) => SystemModule.fromMap(m as Map<String, dynamic>)).toList();
    } catch (e) {
      // TODO: Replace with proper logging service
      // ignore: avoid_print
      print('Error fetching enabled modules: $e');
      return [];
    }
  }
}
