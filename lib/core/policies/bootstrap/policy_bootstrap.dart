/// ============================================================
/// POLICY BOOTSTRAP — INITIALIZATION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/bootstrap/ = policy initialization
///
/// Initializes the Policy Framework during app startup.
/// Must execute after entity context and capability profile
/// are available.
///
/// ✅ Responsibilities:
///   - Initialize the policy repository
///   - Register all default policy rules in the registry
///   - Load effective policy and cache locally
///   - Create PolicyEngine
///   - Register providers
///
/// ❌ Does NOT:
///   - Render UI
///   - Import Flutter widgets
///   - Replace capability bootstrap
///   - Replace feature flag bootstrap
/// ============================================================
library;

import 'package:famhub_app/core/policies/registry/policy_rule_registry.dart';

/// ============================================================
/// BOOTSTRAP POLICY FRAMEWORK
/// ============================================================
///
/// Call this once during app initialization, after
/// capability bootstrap.
///
/// Usage (in startup coordinator):
///   await bootstrapPolicies();
/// ============================================================
Future<void> bootstrapPolicies() async {
  // ── 1. Register all default policy rule declarations ──
  PolicyRuleRegistry.registerDefaults();

  // ── 2. Repository initialization ──
  // The repository is lazy-initialized via Riverpod provider.
  // No eager initialization needed here.

  // ── 3. Policy engine creation ──
  // The engine is created lazily via policyEngineProvider
  // when effectivePolicyProvider resolves.
  // No eager initialization needed here.

  // Log completion
  // ignore: avoid_print
  print('[POLICIES] Bootstrap complete — '
      '${PolicyRuleRegistry.registeredPolicyIds.length} policy rules registered');
}

/// ============================================================
/// BOOTSTRAP POLICY FRAMEWORK (SYNC VARIANT)
/// ============================================================
///
/// Synchronous version for cases where async is not needed.
/// All registration is synchronous.
/// ============================================================
void bootstrapPoliciesSync() {
  PolicyRuleRegistry.registerDefaults();

  // ignore: avoid_print
  print('[POLICIES] Bootstrap complete (sync) — '
      '${PolicyRuleRegistry.registeredPolicyIds.length} policy rules registered');
}
