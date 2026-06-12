import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/access/domain/models/access_decision.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_tier.dart';
import 'package:famhub_app/core/feature_flags/application/providers/feature_access_provider.dart';

/// ============================================================
/// ACCESS STATE PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// Provides current access state snapshot.
///
/// 🧠 LOCATION CONTEXT:
///   core/feature_flags/application/providers/
///     = runtime access state (correct location)
/// ============================================================

final accessStateProvider = Provider((ref) {
  final engine = ref.read(accessDecisionEngineProvider);
  // Return a simple access state object
  return _AccessStateSnapshot(engine);
});

class _AccessStateSnapshot {
  final AccessDecisionEngine engine;

  _AccessStateSnapshot(this.engine);

  AccessDecision checkAccess({
    required String featureKey,
    required String permission,
    required String role,
    required SubscriptionTier userTier,
  }) {
    return engine.evaluate(
      featureKey: featureKey,
      permission: permission,
      role: role,
      userTier: userTier,
    );
  }
}