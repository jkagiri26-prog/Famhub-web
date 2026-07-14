/// ============================================================
/// POLICY RULE REGISTRY — PURE DECLARATIONS CATALOG
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/registry/ = policy registry layer
///
/// The registry is a pure declaration catalog. It contains
/// NO business logic, NO evaluation, NO values.
///
/// Every policy rule is declared here. This is the single source
/// of truth for what policy rules exist in the system.
///
/// This is NOT values. Only rule declarations/metadata.
///
/// ✅ Responsibilities:
///   - Register all known policy rules
///   - Define metadata for each rule (id, name, description, domain)
///   - Pure lookups and queries
///
/// ❌ Does NOT:
///   - Contain rule values
///   - Evaluate policies
///   - Import providers or UI
///   - Contain business logic
/// ============================================================
library;

import 'package:famhub_app/core/policies/domain/policy.dart';

/// ============================================================
/// POLICY RULE REGISTRATION ENTRY
/// ============================================================
///
/// Binds a Policy declaration to the registry.
/// ============================================================
class PolicyRuleRegistration {
  /// The policy rule being registered
  final Policy policy;

  /// Expected value type
  final String valueType;

  /// Default value when no backend value is provided
  final dynamic defaultValue;

  const PolicyRuleRegistration({
    required this.policy,
    this.valueType = 'bool',
    this.defaultValue,
  });
}

/// ============================================================
/// POLICY RULE REGISTRY
/// ============================================================
///
/// Static registry where all policy rules are declared.
/// This is the permanent catalog — policy rules are contracts
/// and should not be removed once registered.
///
/// Contains ONLY metadata. NEVER values.
/// ============================================================
class PolicyRuleRegistry {
  static final Map<String, PolicyRuleRegistration> _registry = {};

  /// ============================================================
  /// REGISTER A POLICY RULE
  /// ============================================================
  ///
  /// Registers a policy rule declaration.
  /// Must be called during app initialization.
  /// ============================================================
  static void register(PolicyRuleRegistration registration) {
    _registry[registration.policy.id] = registration;
  }

  /// ============================================================
  /// REGISTER ALL DEFAULT POLICY RULES
  /// ============================================================
  ///
  /// Convenience method to register all system policy rules
  /// with their default metadata.
  ///
  /// Called once during app bootstrap.
  /// ============================================================
  static void registerDefaults() {
    // ── Workflow ──
    register(const PolicyRuleRegistration(
      policy: Policies.workflowExecution,
      defaultValue: true,
    ));

    // ── Inventory ──
    register(const PolicyRuleRegistration(
      policy: Policies.inventoryTracking,
      defaultValue: true,
    ));

    // ── Marketplace ──
    register(const PolicyRuleRegistration(
      policy: Policies.marketplaceSelling,
      defaultValue: true,
    ));
    register(const PolicyRuleRegistration(
      policy: Policies.marketplaceBuying,
      defaultValue: true,
    ));
    register(const PolicyRuleRegistration(
      policy: Policies.marketplaceOrders,
      defaultValue: true,
    ));

    // ── Upload ──
    register(const PolicyRuleRegistration(
      policy: Policies.maxImageUpload,
      valueType: 'int',
      defaultValue: 6,
    ));

    // ── Traceability ──
    register(const PolicyRuleRegistration(
      policy: Policies.traceability,
      defaultValue: true,
    ));

    // ── Finance ──
    register(const PolicyRuleRegistration(
      policy: Policies.financeRecording,
      defaultValue: true,
    ));

    // ── Analytics ──
    register(const PolicyRuleRegistration(
      policy: Policies.analytics,
      defaultValue: true,
    ));

    // ── AI ──
    register(const PolicyRuleRegistration(
      policy: Policies.aiAssistant,
      defaultValue: false,
    ));

    // ── Staff ──
    register(const PolicyRuleRegistration(
      policy: Policies.staffManagement,
      defaultValue: true,
    ));

    // ── Export ──
    register(const PolicyRuleRegistration(
      policy: Policies.exportCertification,
      defaultValue: false,
    ));

    // ── Cold Chain ──
    register(const PolicyRuleRegistration(
      policy: Policies.coldChain,
      defaultValue: false,
    ));

    // ── Logistics ──
    register(const PolicyRuleRegistration(
      policy: Policies.logistics,
      defaultValue: true,
    ));

    // ── Contract Farming ──
    register(const PolicyRuleRegistration(
      policy: Policies.contractFarming,
      defaultValue: false,
    ));

    // ── Region ──
    register(const PolicyRuleRegistration(
      policy: Policies.regionRestriction,
      valueType: 'List<String>',
      defaultValue: <String>[],
    ));
  }

  // ============================================================
  // QUERY METHODS
  // ============================================================

  /// Get a policy rule registration by its id.
  static PolicyRuleRegistration? get(String policyId) {
    return _registry[policyId];
  }

  /// Check if a policy rule is registered.
  static bool hasPolicy(String policyId) {
    return _registry.containsKey(policyId);
  }

  /// Get all registered policy rule IDs.
  static List<String> get registeredPolicyIds =>
      _registry.keys.toList();

  /// Get all registered policies.
  static List<Policy> get allPolicies =>
      _registry.values.map((r) => r.policy).toList();

  /// Get all registrations.
  static List<PolicyRuleRegistration> get allRegistrations =>
      _registry.values.toList();

  /// Get all policies for a given domain.
  static List<PolicyRuleRegistration> forDomain(String domain) {
    return _registry.values
        .where((r) => r.policy.domain == domain)
        .toList();
  }

  /// Get the default value for a policy rule.
  static dynamic defaultValueFor(String policyId) {
    return _registry[policyId]?.defaultValue;
  }

  /// Get the expected value type for a policy rule.
  static String valueTypeFor(String policyId) {
    return _registry[policyId]?.valueType ?? 'bool';
  }

  /// Clear all registrations (testing / hot reload).
  static void clear() {
    _registry.clear();
  }
}
