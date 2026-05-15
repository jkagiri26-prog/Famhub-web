import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../rules/application/providers/access_policy_provider.dart';
import '../subscription/domain/models/subscription_tier.dart';

class AccessDecisionEngine {
  static bool canAccess({
    required String featureKey,
    required String permission,
    required String role,
    required SubscriptionTier userTier,
    required Map<String, dynamic> policyData,
  }) {
    final rolePermissions =
        Map<String, List<String>>.from(policyData['rolePermissions']);

    final featureTiers =
        Map<String, SubscriptionTier>.from(policyData['featureTiers']);

    // Role check
    final allowedPermissions = rolePermissions[role] ?? [];
    final roleAllowed =
        allowedPermissions.any((p) => permission.startsWith(p));

    if (!roleAllowed) return false;

    // Subscription check
    final requiredTier = featureTiers[featureKey] ?? SubscriptionTier.free;

    final tierAllowed = userTier.index >= requiredTier.index;

    return tierAllowed;
  }
}