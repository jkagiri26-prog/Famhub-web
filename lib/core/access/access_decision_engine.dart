import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../subscription/domain/models/subscription_tier.dart';
import 'application/providers/access_policy_provider.dart';
import 'domain/models/access_policy.dart';
import 'domain/models/access_decision.dart';

class AccessDecisionEngine {
  final Ref ref;

  AccessDecisionEngine(this.ref);

  AccessPolicy? _cachedPolicy;

  void _ensurePolicyLoaded() {
    final asyncPolicy = ref.read(accessPolicyProvider);
    _cachedPolicy ??= asyncPolicy.valueOrNull;
  }

  AccessDecision evaluate({
    required String featureKey,
    required String permission,
    required String role,
    required SubscriptionTier userTier,
  }) {
    _ensurePolicyLoaded();

    final policy = _cachedPolicy;

    if (policy == null) {
      return const AccessDecision(
        type: AccessDecisionType.deny,
        reason: 'Policy not loaded',
      );
    }

    final allowedPermissions = policy.rolePermissions[role] ?? [];

    final roleAllowed = allowedPermissions.any(
      (p) => permission.startsWith(p),
    );

    if (!roleAllowed) {
      return const AccessDecision(
        type: AccessDecisionType.deny,
        reason: 'Role not permitted',
      );
    }

    final requiredTier =
        policy.featureTiers[featureKey] ?? SubscriptionTier.free;

    final tierAllowed = userTier.index >= requiredTier.index;

    if (!tierAllowed) {
      return const AccessDecision(
        type: AccessDecisionType.upgradeRequired,
        reason: 'Upgrade required',
      );
    }

    return const AccessDecision(
      type: AccessDecisionType.allow,
    );
  }
}