import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/access/access_decision_engine.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_tier.dart';
import 'package:famhub_app/core/subscription/application/providers/subscription_provider.dart';
import 'package:famhub_app/core/context_engine/providers/ui_context_provider.dart';

/// ============================================================
/// FEATURE ACCESS PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// Evaluates whether a feature is accessible at runtime
/// by combining module state, access permissions, and
/// subscription tier.
///
/// 🧠 LOCATION CONTEXT:
///   core/feature_flags/application/providers/
///     = runtime feature evaluation (correct location)
///
/// ✅ Correct: Application layer coordination
/// ❌ Does NOT: Import UI, registry, or Supabase directly
/// ============================================================

final accessDecisionEngineProvider = Provider((ref) => AccessDecisionEngine(ref));

final subscriptionServiceProvider = Provider((ref) {
  final tier = ref.watch(subscriptionProvider);
  return _SubscriptionAccess(tier);
});

class _SubscriptionAccess {
  final SubscriptionTier _tier;

  _SubscriptionAccess(this._tier);

  bool hasAccess(String moduleKey) {
    // Basic entitlement check based on tier
    // In production, use backend subscription service
    return _tier.index >= SubscriptionTier.free.index;
  }
}

final moduleActiveProvider =
    FutureProvider.family<bool, String>((ref, featureKey) async {
  final moduleService = ref.watch(moduleServiceProvider);
  final modules = await moduleService.getActiveModules();
  return modules.any((m) =>
      m.moduleKey == featureKey && m.isEnabled && m.dashboardVisible);
});

final featureAccessProvider =
    FutureProvider.family<bool, String>((ref, featureKey) async {
  final isActive = await ref.watch(moduleActiveProvider(featureKey).future);
  if (!isActive) return false;

  final accessEngine = ref.watch(accessDecisionEngineProvider);
  final subscriptionAccess = ref.watch(subscriptionServiceProvider);
  final appContext = ref.watch(uiContextProvider);
  final userTier = ref.watch(subscriptionProvider);

  // Access must be granted
  final decision = accessEngine.evaluate(
    featureKey: featureKey,
    permission: 'view_$featureKey',
    role: appContext.role,
    userTier: userTier,
  );

  if (!decision.allowed) return false;

  // Subscription must allow it
  final subscriptionOk = subscriptionAccess.hasAccess(featureKey);
  if (!subscriptionOk) return false;

  return true;
});