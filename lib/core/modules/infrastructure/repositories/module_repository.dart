import '../../domain/models/system_module.dart';
import '../../../services/supabase_service.dart';

class ModuleRepository {
  Future<List<SystemModule>> fetchEnabledModules() async {
    try {
      final response = await SupabaseService.client
          .rpc('get_enabled_modules');
      
      if (response == null) return [];

      final List<dynamic> data = response as List<dynamic>;
      return data.map((m) => SystemModule.fromMap(m as Map<String, dynamic>)).toList();
    } catch (e) {
      // In production, use a proper logging service
      print('Error fetching enabled modules: $e');
      return [];
    }
  }
}
