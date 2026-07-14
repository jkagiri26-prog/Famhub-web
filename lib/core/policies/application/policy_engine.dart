/// ============================================================
/// POLICY ENGINE — PURE LOCATION POLICY EVALUATOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/application/ = policy application layer
///
/// The Policy Engine is the SINGLE entry point for all location
/// policy checks in the application. Every module, workflow,
/// widget, and service MUST use this engine instead of hardcoded
/// location or country checks.
///
/// ✅ Responsibilities:
///   - Evaluate policy rules by key
///   - Expose typed helpers: isAllowed, getNumber, getString, etc.
///   - O(1) map lookup — no loops, no database, no async
///   - Cache resolved policy for performance
///
/// ❌ Does NOT:
///   - Perform UI rendering
///   - Perform database writes
///   - Import Flutter UI
///   - Replace CapabilityEngine (different concerns)
///   - Replace RuntimeFeatureFlags (different concerns)
///   - Replace AccessDecisionEngine (different concerns)
///
/// ✅ ARCHITECTURE PRINCIPLE:
///   Instead of:
///     if (country == 'Kenya') → show X
///     if (region == 'North') → show Y
///
///   Always use:
///     engine.isAllowed(Policies.workflowExecution)
///     engine.getNumber(Policies.maxImageUpload)
///
///   Every location-based behavior difference originates from
///   the Policy Framework.
/// ============================================================
library;

import 'package:famhub_app/core/policies/domain/policy.dart';
import 'package:famhub_app/core/policies/domain/effective_policy.dart';

/// ============================================================
/// POLICY ENGINE
/// ============================================================
///
/// Pure evaluation engine. All policy decisions flow
/// through this engine. Evaluation is O(1) map lookup.
/// ============================================================
class PolicyEngine {
  /// The resolved effective policy
  final EffectivePolicy policy;

  /// Cache for fast boolean lookups
  final Map<String, bool> _booleanCache = {};
  final Map<String, int> _numberCache = {};
  final Map<String, double> _decimalCache = {};
  final Map<String, String> _stringCache = {};
  final Map<String, List<String>> _listCache = {};

  PolicyEngine({required this.policy});

  /// ============================================================
  /// FACTORY: CREATE FROM POLICY
  /// ============================================================
  factory PolicyEngine.fromPolicy(EffectivePolicy policy) =>
      PolicyEngine(policy: policy);

  /// ============================================================
  /// FACTORY: CREATE WITH DEFAULTS (FOR TESTING)
  /// ============================================================
  factory PolicyEngine.withDefaults({
    required String organizationId,
    required String locationId,
    bool allowAll = false,
  }) =>
      PolicyEngine(
        policy: EffectivePolicy(
          rules: {
            'workflow.execution': allowAll,
            'inventory.tracking': allowAll,
            'marketplace.selling': allowAll,
            'marketplace.buying': allowAll,
            'marketplace.orders': allowAll,
            'upload.max_images': allowAll ? 10 : 3,
            'traceability.enabled': allowAll,
            'finance.recording': allowAll,
            'analytics.enabled': allowAll,
            'ai.assistant': allowAll,
            'staff.management': allowAll,
            'export.certification': allowAll,
            'coldchain.enabled': allowAll,
            'logistics.enabled': allowAll,
            'contract.farming': allowAll,
            'region.restriction': allowAll
                ? <String>[]
                : <String>['restricted'],
          },
          locationId: locationId,
          organizationId: organizationId,
        ),
      );

  /// ============================================================
  /// IS ALLOWED
  /// ============================================================
  ///
  /// Returns true if the policy rule evaluates to a truthy value.
  /// Accepts either a Policy object or a string key.
  ///
  /// This is the PRIMARY method for boolean policy checks.
  /// Usage:
  ///   engine.isAllowed(Policies.workflowExecution)
  ///   engine.isAllowed(Policies.traceability)
  /// ============================================================
  bool isAllowed(Object policyRef) {
    final key = _resolveKey(policyRef);

    // Check cache
    if (_booleanCache.containsKey(key)) {
      return _booleanCache[key]!;
    }

    final result = policy.getBoolean(key);
    _booleanCache[key] = result;
    return result;
  }

  /// ============================================================
  /// GET BOOLEAN
  /// ============================================================
  ///
  /// Explicit boolean check. Same as isAllowed but explicit.
  /// ============================================================
  bool getBoolean(Object policyRef) => isAllowed(policyRef);

  /// ============================================================
  /// GET NUMBER
  /// ============================================================
  ///
  /// Returns the integer value of a policy rule.
  /// Returns 0 if the rule is not found.
  ///
  /// Usage:
  ///   final maxImages = engine.getNumber(Policies.maxImageUpload);
  ///   // Never hardcode 3, 5, 10 — always use policy
  /// ============================================================
  int getNumber(Object policyRef) {
    final key = _resolveKey(policyRef);

    if (_numberCache.containsKey(key)) {
      return _numberCache[key]!;
    }

    final result = policy.getNumber(key);
    _numberCache[key] = result;
    return result;
  }

  /// ============================================================
  /// GET DECIMAL
  /// ============================================================
  ///
  /// Returns the double value of a policy rule.
  /// Returns 0.0 if the rule is not found.
  /// ============================================================
  double getDecimal(Object policyRef) {
    final key = _resolveKey(policyRef);

    if (_decimalCache.containsKey(key)) {
      return _decimalCache[key]!;
    }

    final result = policy.getDecimal(key);
    _decimalCache[key] = result;
    return result;
  }

  /// ============================================================
  /// GET STRING
  /// ============================================================
  ///
  /// Returns the string value of a policy rule.
  /// Returns empty string if the rule is not found.
  /// ============================================================
  String getString(Object policyRef) {
    final key = _resolveKey(policyRef);

    if (_stringCache.containsKey(key)) {
      return _stringCache[key]!;
    }

    final result = policy.getString(key);
    _stringCache[key] = result;
    return result;
  }

  /// ============================================================
  /// GET LIST
  /// ============================================================
  ///
  /// Returns the list value of a policy rule.
  /// Returns empty list if the rule is not found.
  /// ============================================================
  List<String> getList(Object policyRef) {
    final key = _resolveKey(policyRef);

    if (_listCache.containsKey(key)) {
      return List.unmodifiable(_listCache[key]!);
    }

    final result = policy.getList(key);
    _listCache[key] = result;
    return List.unmodifiable(result);
  }

  /// ============================================================
  /// GET VALUE
  /// ============================================================
  ///
  /// Returns the raw dynamic value of a policy rule.
  /// Returns null if the rule is not found.
  /// ============================================================
  dynamic getValue(Object policyRef) {
    final key = _resolveKey(policyRef);
    return policy.getValue(key);
  }

  /// ============================================================
  /// HAS RULE
  /// ============================================================
  ///
  /// Returns true if the rule exists in the policy.
  /// ============================================================
  bool hasRule(Object policyRef) {
    final key = _resolveKey(policyRef);
    return policy.hasRule(key);
  }

  /// ============================================================
  /// ALL RULES
  /// ============================================================
  ///
  /// Returns the full rules map from the policy.
  /// ============================================================
  Map<String, dynamic> get allRules =>
      Map<String, dynamic>.from(policy.rules);

  /// ============================================================
  /// METADATA
  /// ============================================================
  String get locationId => policy.locationId;
  String get organizationId => policy.organizationId;
  String get version => policy.version;

  /// ============================================================
  /// INVALIDATE CACHE
  /// ============================================================
  ///
  /// Call when the policy changes to force re-evaluation.
  /// ============================================================
  void invalidateCache() {
    _booleanCache.clear();
    _numberCache.clear();
    _decimalCache.clear();
    _stringCache.clear();
    _listCache.clear();
  }

  /// ============================================================
  /// REPLACE POLICY
  /// ============================================================
  ///
  /// Replace the underlying policy and invalidate cache.
  /// ============================================================
  void replacePolicy(EffectivePolicy newPolicy) {
    // policy is final — this is a conceptual guide.
    // Callers should create a new PolicyEngine with the new policy.
    invalidateCache();
  }

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  String _resolveKey(Object policyRef) {
    if (policyRef is Policy) {
      return policyRef.id;
    }
    if (policyRef is String) {
      return policyRef;
    }
    throw ArgumentError(
      'Policy must be a Policy object or a String key. '
      'Got: ${policyRef.runtimeType}',
    );
  }
}
