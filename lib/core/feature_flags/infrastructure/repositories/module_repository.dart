import 'package:famhub_app/core/services/supabase_service.dart';

/// ============================================================
/// MODULE REPOSITORY (INFRASTRUCTURE LAYER)
/// ============================================================
///
/// Fetches module definitions from backend.
///
/// 🧠 LOCATION CONTEXT:
///   core/feature_flags/infrastructure/repositories/
///     = data access layer (correct location)
///
/// Supabase calls are ALLOWED here (infrastructure layer).
/// ============================================================
class ModuleRepository {
  const ModuleRepository();

  Future<List<Map<String, dynamic>>> fetchModules() async {
    final response =
        await SupabaseService.client.from('system.modules').select();

    return List<Map<String, dynamic>>.from(response);
  }
}