/// ============================================================
/// POLICY SDK — Public facade for policy evaluation
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/sdk/ = developer-facing SDK layer
///
/// ✅ Responsibilities:
///   - Expose policy checks to feature modules
///   - Delegate to policyEngineProvider
///   - Never expose PolicyEngine directly
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain persistence logic
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/policies/application/policy_provider.dart';
import 'package:famhub_app/core/policies/domain/policy.dart';
import 'api/sdk_annotations.dart';

/// ============================================================
/// POLICY SDK
/// ============================================================
///
/// Feature modules use this instead of reading providers directly.
///
/// Usage:
///   final policies = ref.read(famhubPolicySdkProvider);
///   if (policies.isAllowed(Policies.workflowExecution)) { ... }
///   final maxImages = policies.number(Policies.maxImageUpload);
///   final regionList = policies.list(Policies.regionRestriction);
/// ============================================================
@publicSdk()
class PolicySdk {
  final Ref _ref;

  PolicySdk(this._ref);

  /// Check if a specific policy rule allows something
  @SdkMethod(version: '1.0.0')
  bool isAllowed(Object policyRef) =>
      _ref.read(policyBooleanProvider(policyRef));

  /// Get the integer value of a policy rule
  @SdkMethod(version: '1.0.0')
  int number(Object policyRef) =>
      _ref.read(policyNumberProvider(policyRef));

  /// Get the string value of a policy rule
  @SdkMethod(version: '1.0.0')
  String text(Object policyRef) =>
      _ref.read(policyStringProvider(policyRef));

  /// Get the list value of a policy rule
  @SdkMethod(version: '1.0.0')
  List<String> list(Object policyRef) =>
      _ref.read(policyListProvider(policyRef));

  /// Get the raw dynamic value of a policy rule
  @SdkMethod(version: '1.0.0')
  dynamic value(Object policyRef) =>
      _ref.read(policyValueProvider(policyRef));

  /// Check if a policy rule exists
  @SdkMethod(version: '1.0.0')
  bool hasRule(Object policyRef) =>
      _ref.read(hasPolicyRuleProvider(policyRef));

  /// Get all policy rules as a map
  @SdkMethod(version: '1.0.0')
  Map<String, dynamic> allRules() =>
      _ref.read(allPolicyRulesProvider);

  /// Get the effective policy's location ID
  @SdkMethod(version: '1.0.0')
  String get locationId {
    final engine = _ref.read(policyEngineProvider);
    return engine?.locationId ?? '';
  }

  /// Get the effective policy's version
  @SdkMethod(version: '1.0.0')
  String get version {
    final engine = _ref.read(policyEngineProvider);
    return engine?.version ?? '';
  }
}

/// ============================================================
/// PROVIDER: POLICY SDK
/// ============================================================
@SdkProvider()
final famhubPolicySdkProvider = Provider<PolicySdk>((ref) {
  return PolicySdk(ref);
});

