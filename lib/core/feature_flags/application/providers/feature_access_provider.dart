import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/access/access_decision_engine.dart';
import 'package:famhub_app/core/context_engine/providers/ui_context_provider.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/subscription/application/providers/subscription_entitlements_provider.dart';
import 'package:famhub_app/core/subscription/application/providers/subscription_provider.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_tier.dart';

/// ============================================================
/// FEATURE ACCESS PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// Evaluates whether a feature is accessible at runtime by combining module
/// state, role/permission checks and canonical subscription capabilities.
///
/// Paid modules use the backend-authoritative entitlement resolver. Free
/// modules keep the existing tier path. No client plan mapping is used.
/// ============================================================

final accessDecisionEngineProvider = Provider(
  (ref) => AccessDecisionEngine(ref),
);

final subscriptionServiceProvider = Provider((ref) {
  final tier = ref.watch(subscriptionProvider);
  return _SubscriptionAccess(tier);
});

class _SubscriptionAccess {
  final SubscriptionTier _tier;

  _SubscriptionAccess(this._tier);

  bool hasAccess(String moduleKey) {
    // Preserved for free/basic modules and legacy callers.
    return _tier.index >= SubscriptionTier.free.index;
  }
}

final moduleActiveProvider = FutureProvider.family<bool, String>((
  ref,
  featureKey,
) async {
  final moduleService = ref.watch(moduleServiceProvider);
  final modules = await moduleService.getActiveModules();
  return modules.any(
    (m) => m.moduleKey == featureKey && m.isEnabled && m.dashboardVisible,
  );
});

final featureAccessProvider = FutureProvider.family<bool, String>((
  ref,
  featureKey,
) async {
  final moduleService = ref.watch(moduleServiceProvider);
  final modules = await moduleService.getActiveModules();

  SystemModule? module;
  for (final candidate in modules) {
    if (candidate.moduleKey == featureKey &&
        candidate.isEnabled &&
        candidate.dashboardVisible) {
      module = candidate;
      break;
    }
  }
  if (module == null) return false;

  final accessEngine = ref.watch(accessDecisionEngineProvider);
  final subscriptionAccess = ref.watch(subscriptionServiceProvider);
  final appContext = ref.watch(uiContextProvider);
  final userTier = ref.watch(subscriptionProvider);
  final requiresPaidEntitlement =
      module.requiresSubscription || module.premiumOnly;

  // Roles, entity membership and module permissions remain authoritative.
  // Paid modules replace the client tier gate with canonical capabilities.
  final decision = accessEngine.evaluate(
    featureKey: featureKey,
    permission: 'view_$featureKey',
    role: appContext.role,
    userTier: userTier,
    checkTier: !requiresPaidEntitlement,
  );

  if (!decision.allowed) return false;

  if (requiresPaidEntitlement) {
    final entitlements = ref
        .watch(subscriptionEntitlementsProvider)
        .asData
        ?.value;
    // Loading, error, unverified or empty capabilities fail closed.
    if (entitlements == null || !entitlements.allowsModule(featureKey)) {
      return false;
    }
  } else {
    final subscriptionOk = subscriptionAccess.hasAccess(featureKey);
    if (!subscriptionOk) return false;
  }

  return true;
});
