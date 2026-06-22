import 'package:famhub_app/core/services/supabase_service.dart';

/// ============================================================
/// ACCESS REPOSITORY (INFRASTRUCTURE LAYER)
/// ============================================================
///
/// Fetches access context from backend.
///
/// 🧠 LOCATION CONTEXT:
///   core/feature_flags/infrastructure/repositories/
///     = data access layer (correct location)
///
/// Supabase calls are ALLOWED here (infrastructure layer).
/// ============================================================
class AccessRepository {
  const AccessRepository();

  Future<Map<String, dynamic>> fetchAccessContext() async {
    final response =
        await SupabaseService.instance.client.rpc('get_access_context');

    return Map<String, dynamic>.from(response ?? {});
  }
}