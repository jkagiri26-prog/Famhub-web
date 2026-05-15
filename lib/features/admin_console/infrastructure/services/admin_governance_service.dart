import '../../../core/services/supabase_service.dart';

class AdminGovernanceService {
  final client = SupabaseService.client;

  Future<void> toggleFeature(String featureKey, bool enabled) async {
    await client.rpc('update_feature_flag', params: {
      'feature_key': featureKey,
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