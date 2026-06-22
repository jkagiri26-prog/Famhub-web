import 'package:famhub_app/core/services/supabase_service.dart';

class AdminGovernanceService {
  final client = SupabaseService.instance.client;

  Future<void> toggleFeature(String featureKey, bool enabled) async {
    await client.rpc('update_feature_flag', params: {
      'feature_key': featureKey,
      'enabled': enabled,
    });
  }

  Future<void> toggleModule({
    required String moduleKey,
    required bool enabled,
  }) async {
    await client.rpc('toggle_module', params: {
      'module_key': moduleKey,
      'enabled': enabled,
    });
  }

  Future<void> updateRolePermission(
    String role,
    String permission,
  ) async {
    await client.rpc('update_role_permission', params: {
      'role': role,
      'permission': permission,
    });
  }

  Future<void> updateFeatureTier(
    String featureKey,
    String tier,
  ) async {
    await client.rpc('update_feature_tier', params: {
      'feature_key': featureKey,
      'tier': tier,
    });
  }
}