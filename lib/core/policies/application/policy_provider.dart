/// ============================================================
/// POLICY ENGINE PROVIDER — RUNTIME BRIDGE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/application/ = policy application layer
///
/// These Riverpod providers bridge the Policy Engine with the
/// rest of the application. They are the runtime connection
/// between the effective policy and every rendering decision.
///
/// ✅ Responsibilities:
///   - Expose PolicyEngine through Riverpod
///   - Auto-invalidate on context/location changes
///   - Provide convenient typed policy query providers
///
/// ❌ Does NOT:
///   - Perform UI rendering
///   - Evaluate capabilities
///   - Check feature flags
///   - Check access permissions
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/policies/domain/policy.dart';
import 'package:famhub_app/core/policies/application/policy_engine.dart';
import 'package:famhub_app/core/policies/application/effective_policy_provider.dart';

/// ============================================================
/// PROVIDER: POLICY ENGINE
/// ============================================================
///
/// The main policy engine provider. Rebuilds whenever the
/// effective policy changes.
///
/// All modules, workflows, and components use this provider
/// to check location-based policies.
/// ============================================================
final policyEngineProvider = Provider<PolicyEngine?>((ref) {
  final asyncPolicy = ref.watch(effectivePolicyProvider);
  final effectivePolicy = asyncPolicy.whenOrNull(
    data: (data) => data,
  );
  if (effectivePolicy == null) return null;
  return PolicyEngine.fromPolicy(effectivePolicy);
});

/// ============================================================
/// PROVIDER: POLICY BOOLEAN (IS ALLOWED)
/// ============================================================
///
/// Family provider to check if a specific policy rule allows something.
/// Usage:
///   final canExecute = ref.watch(policyBooleanProvider(Policies.workflowExecution));
///   final canTrace = ref.watch(policyBooleanProvider(Policies.traceability));
/// ============================================================
final policyBooleanProvider = Provider.family<bool, Object>((ref, policyRef) {
  final engine = ref.watch(policyEngineProvider);
  if (engine == null) return false;
  return engine.isAllowed(policyRef);
});

/// ============================================================
/// PROVIDER: POLICY NUMBER
/// ============================================================
///
/// Family provider to get the integer value of a policy rule.
/// Usage:
///   final maxImages = ref.watch(policyNumberProvider(Policies.maxImageUpload));
/// ============================================================
final policyNumberProvider = Provider.family<int, Object>((ref, policyRef) {
  final engine = ref.watch(policyEngineProvider);
  if (engine == null) return 0;
  return engine.getNumber(policyRef);
});

/// ============================================================
/// PROVIDER: POLICY STRING
/// ============================================================
///
/// Family provider to get the string value of a policy rule.
/// ============================================================
final policyStringProvider = Provider.family<String, Object>((ref, policyRef) {
  final engine = ref.watch(policyEngineProvider);
  if (engine == null) return '';
  return engine.getString(policyRef);
});

/// ============================================================
/// PROVIDER: POLICY LIST
/// ============================================================
///
/// Family provider to get the list value of a policy rule.
/// ============================================================
final policyListProvider = Provider.family<List<String>, Object>((ref, policyRef) {
  final engine = ref.watch(policyEngineProvider);
  if (engine == null) return [];
  return engine.getList(policyRef);
});

/// ============================================================
/// PROVIDER: POLICY VALUE
/// ============================================================
///
/// Family provider to get the raw dynamic value of a policy rule.
/// ============================================================
final policyValueProvider = Provider.family<dynamic, Object>((ref, policyRef) {
  final engine = ref.watch(policyEngineProvider);
  if (engine == null) return null;
  return engine.getValue(policyRef);
});

/// ============================================================
/// PROVIDER: HAS POLICY RULE
/// ============================================================
///
/// Family provider to check if a policy rule exists.
/// ============================================================
final hasPolicyRuleProvider = Provider.family<bool, Object>((ref, policyRef) {
  final engine = ref.watch(policyEngineProvider);
  if (engine == null) return false;
  return engine.hasRule(policyRef);
});

/// ============================================================
/// PROVIDER: ALL POLICY RULES
/// ============================================================
///
/// Returns the full policy rules map.
/// ============================================================
final allPolicyRulesProvider = Provider<Map<String, dynamic>>((ref) {
  final engine = ref.watch(policyEngineProvider);
  if (engine == null) return {};
  return engine.allRules;
});
