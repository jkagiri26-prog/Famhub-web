import '../../../services/api_service.dart';
import '../../../subscription/domain/models/subscription_tier.dart';
import '../../domain/models/access_policy.dart';

class AccessPolicyRepository {
  Future<AccessPolicy> fetchPolicy() async {
    final response =
        await SupabaseService.client.rpc('get_access_policy');

    if (response == null || response is! Map<String, dynamic>) {
      return AccessPolicy.empty();
    }

    final data = response;

    final rolePermissionsRaw =
        data['role_permissions'] as Map<String, dynamic>? ?? {};

    final featureTiersRaw =
        data['feature_tiers'] as Map<String, dynamic>? ?? {};

    final rolePermissions = rolePermissionsRaw.map(
      (key, value) => MapEntry(
        key,
        List<String>.from(value as List? ?? const []),
      ),
    );

    final featureTiers = featureTiersRaw.map(
      (key, value) {
        final tierString = value?.toString().toLowerCase();

        final tier = SubscriptionTier.values.firstWhere(
          (e) => e.name.toLowerCase() == tierString,
          orElse: () => SubscriptionTier.free,
        );

        return MapEntry(key, tier);
      },
    );

    return AccessPolicy(
      rolePermissions: rolePermissions,
      featureTiers: featureTiers,
    );
  }
}