import '../../subscription/domain/models/subscription_tier.dart';

class AccessPolicy {
  final Map<String, List<String>> rolePermissions;
  final Map<String, SubscriptionTier> featureTiers;

  const AccessPolicy({
    required this.rolePermissions,
    required this.featureTiers,
  });

  factory AccessPolicy.empty() {
    return const AccessPolicy(
      rolePermissions: {},
      featureTiers: {},
    );
  }
}