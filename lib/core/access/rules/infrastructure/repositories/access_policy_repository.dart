import '../../services/supabase_service.dart';
import '../../subscription/domain/models/subscription_tier.dart';
import '../domain/models/access_policy.dart';

class AccessPolicyRepository {
  Future<AccessPolicy> fetchPolicy() async {
    final response =
        await SupabaseService.client.rpc('get_access_policy');

    if (response == null) {
      return AccessPolicy.empty();
    }

    final data = response as Map<String, dynamic>;

    final rolePermissions =
        Map<String, List<String>>.from(data['role_permissions']);

    final featureTiers =
        (data['feature_tiers'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        SubscriptionTier.values.byName(value),
      ),
    );

    return AccessPolicy(
      rolePermissions: rolePermissions,
      featureTiers: featureTiers,
    );
  }
}