/// ============================================================
/// RUNTIME REQUEST — UNIVERSAL DECISION INPUT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/runtime_decision/domain/ = domain layer
///
/// The RuntimeRequest is the SINGLE input model for all runtime
/// permission decisions. Every engine check (capability, policy,
/// access, feature flag) is evaluated from this request.
///
/// ✅ Responsibilities:
///   - Carry all data needed for a complete decision
///   - Action: what the user wants to do
///   - Module: which module the action belongs to
///   - Capability: optional capability identifier
///   - Policy: optional policy key
///   - Permission: optional permission string
///   - FeatureFlag: optional feature flag key
///
/// ✅ ARCHITECTURE PRINCIPLE:
///   Instead of:
///     final capOk = engine.hasCapability('workflow.execution');
///     final policyOk = policy.isAllowed('workflow.execution');
///     final accessOk = access.evaluate(...);
///     final flagOk = flags.isEnabled('workflow');
///
///   Always use:
///     final decision = runtimeDecision.evaluate(RuntimeRequest(
///       action: 'workflow.execute',
///       module: 'workflow',
///       capability: 'workflow.execution',
///       policy: 'workflow.execution',
///       permission: 'workflow.execute',
///       featureFlag: 'workflow_enabled',
///     ));
///
/// ❌ Does NOT:
///   - Execute any business logic
///   - Access Supabase
///   - Perform async operations
///   - Import Flutter UI
/// ============================================================
library;

/// ============================================================
/// RUNTIME REQUEST
/// ============================================================
///
/// Universal input for the Runtime Decision Engine.
/// Everything evaluated from this single request model.
/// ============================================================
class RuntimeRequest {
  /// The action being requested (e.g., 'execute', 'render', 'navigate')
  final String action;

  /// The module or feature context (e.g., 'marketplace', 'workflow')
  final String module;

  /// Optional capability identifier for capability engine check
  final String? capability;

  /// Optional policy key for policy engine check
  final String? policy;

  /// Optional permission string for access engine check
  final String? permission;

  /// Optional feature flag key for feature flag check
  final String? featureFlag;

  const RuntimeRequest({
    required this.action,
    required this.module,
    this.capability,
    this.policy,
    this.permission,
    this.featureFlag,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  RuntimeRequest copyWith({
    String? action,
    String? module,
    String? capability,
    String? policy,
    String? permission,
    String? featureFlag,
  }) {
    return RuntimeRequest(
      action: action ?? this.action,
      module: module ?? this.module,
      capability: capability ?? this.capability,
      policy: policy ?? this.policy,
      permission: permission ?? this.permission,
      featureFlag: featureFlag ?? this.featureFlag,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuntimeRequest &&
          action == other.action &&
          module == other.module &&
          capability == other.capability &&
          policy == other.policy &&
          permission == other.permission &&
          featureFlag == other.featureFlag;

  @override
  int get hashCode => Object.hash(
        action,
        module,
        capability,
        policy,
        permission,
        featureFlag,
      );

  @override
  String toString() =>
      'RuntimeRequest(action: $action, module: $module, '
      'capability: $capability, policy: $policy, '
      'permission: $permission, featureFlag: $featureFlag)';
}
