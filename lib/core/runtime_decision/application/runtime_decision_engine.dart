/// ============================================================
/// RUNTIME DECISION ENGINE — SINGLE UNIFIED EVALUATOR
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/runtime_decision/application/ = application layer
///
/// The Runtime Decision Engine is the ONLY component responsible
/// for answering ALL runtime permission questions:
///
///   canRender()      canExecute()      canNavigate()
///   canCreate()      canEdit()         canDelete()
///   canApprove()     canPurchase()     canSell()
///   canExport()      canUpload()       canViewAnalytics()
///   canUseAI()       canManageStaff()  canAccessWorkflow()
///
/// No widget, provider, service, or workflow should ever need
/// to ask capability, policy, access, or feature flag individually.
/// Instead, they ask ONE engine.
///
/// ✅ RESPONSIBILITIES:
///   - Evaluate ALL governance layers in exact order:
///     1. Capability Engine
///     2. Policy Engine
///     3. Access Engine
///     4. Runtime Feature Flags
///   - Stop immediately when one layer denies
///   - Return structured RuntimeDecision with explanation
///   - Provide convenience methods: canExecute, canRender, etc.
///   - Complete each evaluation in O(1) average time
///
/// ❌ Does NOT:
///   - Access Supabase
///   - Perform async work during evaluation
///   - Read repositories directly
///   - Import Flutter UI
///
/// ✅ EVALUATION ORDER (DO NOT CHANGE):
///   Entity Context
///        ↓
///   Capability Engine    ← 1
///        ↓
///   Policy Engine        ← 2
///        ↓
///   Access Engine        ← 3
///        ↓
///   Runtime Feature Flags ← 4
///        ↓
///   Runtime Decision Engine
///        ↓
///   Composition
///        ↓
///   Shell
/// ============================================================
library;

import 'package:famhub_app/core/runtime_decision/domain/runtime_request.dart';
import 'package:famhub_app/core/runtime_decision/domain/runtime_decision.dart';
import 'package:famhub_app/core/runtime_decision/domain/runtime_reason.dart';
import 'package:famhub_app/core/capabilities/application/capability_engine.dart';
import 'package:famhub_app/core/policies/application/policy_engine.dart';
import 'package:famhub_app/core/access/access_decision_engine.dart';
import 'package:famhub_app/core/access/domain/models/access_decision.dart';
import 'package:famhub_app/core/feature_flags/application/services/runtime_feature_flags.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';

/// ============================================================
/// RUNTIME DECISION ENGINE
/// ============================================================
///
/// Pure evaluation engine. Combines every governance layer into
/// one final decision. Stateless — all dependencies injected.
/// ============================================================
class RuntimeDecisionEngine {
  /// Internal engine instances (cached, read-only during evaluation)
  final CapabilityEngine? _capabilityEngine;
  final PolicyEngine? _policyEngine;
  final AccessDecisionEngine? _accessEngine;
  final EntityContext _context;

  /// Runtime flags snapshot (read-only map of flag key → enabled)
  final Map<String, bool> _runtimeFlags;

  const RuntimeDecisionEngine({
    required CapabilityEngine? capabilityEngine,
    required PolicyEngine? policyEngine,
    required AccessDecisionEngine? accessEngine,
    required EntityContext context,
    required Map<String, bool> runtimeFlags,
  })  : _capabilityEngine = capabilityEngine,
        _policyEngine = policyEngine,
        _accessEngine = accessEngine,
        _context = context,
        _runtimeFlags = runtimeFlags;

  // ============================================================
  // PUBLIC API
  // ============================================================

  /// ============================================================
  /// EVALUATE — CORE METHOD
  /// ============================================================
  ///
  /// Evaluates a RuntimeRequest through ALL governance layers
  /// in exact order. Stops immediately at first denial.
  ///
  /// Evaluation Order:
  ///   1. Capability Engine
  ///   2. Policy Engine
  ///   3. Access Engine
  ///   4. Runtime Feature Flags
  ///   5. ALLOW
  ///
  /// Returns a complete RuntimeDecision with explanation.
  /// ============================================================
  RuntimeDecision evaluate(RuntimeRequest request) {
    // ── PHASE 1: Capability Engine ──
    if (request.capability != null && _capabilityEngine != null) {
      if (!_capabilityEngine.hasCapability(request.capability!)) {
        return const RuntimeDecision.denied(
          reason: RuntimeReasons.capabilityNotAvailable,
          source: RuntimeSources.capabilityEngine,
          failedChecks: [RuntimeCheckCodes.CAPABILITY_DISABLED],
        );
      }
    }

    // ── PHASE 2: Policy Engine ──
    if (request.policy != null && _policyEngine != null) {
      if (_policyEngine.hasRule(request.policy!)) {
        if (!_policyEngine.isAllowed(request.policy!)) {
          return const RuntimeDecision.denied(
            reason: RuntimeReasons.policyDenied,
            source: RuntimeSources.policyEngine,
            failedChecks: [RuntimeCheckCodes.POLICY_DENIED],
          );
        }
      }
    }

    // ── PHASE 3: Access Engine ──
    if (request.permission != null && _accessEngine != null) {
      final accessDecision = _evaluateAccess(request);
      if (!accessDecision.allowed) {
        final failedCheck = accessDecision.type ==
                AccessDecisionType.upgradeRequired
            ? RuntimeCheckCodes.ACCESS_UPGRADE_REQUIRED
            : RuntimeCheckCodes.ACCESS_ROLE_DENIED;
        return RuntimeDecision.denied(
          reason: accessDecision.reason ??
              RuntimeReasons.accessPermissionDenied,
          source: RuntimeSources.accessEngine,
          failedChecks: [failedCheck],
        );
      }
    }

    // ── PHASE 4: Runtime Feature Flags ──
    if (request.featureFlag != null) {
      final flagResult = _evaluateFeatureFlags(request);
      if (!flagResult.allowed) {
        return RuntimeDecision.denied(
          reason: flagResult.reason,
          source: RuntimeSources.featureFlags,
          failedChecks: flagResult.failedChecks,
        );
      }
    }

    // ── PHASE 5: ALLOW ──
    return const RuntimeDecision.allowed();
  }

  // ============================================================
  // CONVENIENCE METHODS
  // ============================================================

  /// ============================================================
  /// CAN EXECUTE
  /// ============================================================
  ///
  /// Check if a workflow, operation, or process can be executed.
  /// ============================================================
  bool canExecute(String module, String action) {
    return evaluate(RuntimeRequest(
      action: action,
      module: module,
      capability: '$module.$action',
      policy: '$module.$action',
      permission: '$module.$action',
      featureFlag: '${module}_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN RENDER
  /// ============================================================
  ///
  /// Check if a widget, component, or UI element should render.
  /// ============================================================
  bool canRender(String module, String widget) {
    return evaluate(RuntimeRequest(
      action: 'render',
      module: module,
      capability: '$module.$widget',
      policy: '$module.$widget',
      permission: '$module.render',
      featureFlag: '${module}_${widget}_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN NAVIGATE
  /// ============================================================
  ///
  /// Check if navigation to a module/route is allowed.
  /// ============================================================
  bool canNavigate(String module) {
    return evaluate(RuntimeRequest(
      action: 'navigate',
      module: module,
      capability: '$module.navigation',
      policy: '$module.navigation',
      permission: '$module.access',
      featureFlag: '${module}_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN APPROVE
  /// ============================================================
  ///
  /// Check if the user can approve a workflow item.
  /// ============================================================
  bool canApprove(String module) {
    return evaluate(RuntimeRequest(
      action: 'approve',
      module: module,
      capability: '$module.approval',
      policy: '$module.approval',
      permission: '$module.approve',
      featureFlag: '${module}_approval_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN DELETE
  /// ============================================================
  ///
  /// Check if the user can delete an item.
  /// ============================================================
  bool canDelete(String module) {
    return evaluate(RuntimeRequest(
      action: 'delete',
      module: module,
      capability: '$module.delete',
      policy: '$module.delete',
      permission: '$module.delete',
      featureFlag: '${module}_delete_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN CREATE
  /// ============================================================
  ///
  /// Check if the user can create a new item.
  /// ============================================================
  bool canCreate(String module) {
    return evaluate(RuntimeRequest(
      action: 'create',
      module: module,
      capability: '$module.create',
      policy: '$module.create',
      permission: '$module.create',
      featureFlag: '${module}_create_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN EDIT
  /// ============================================================
  ///
  /// Check if the user can edit an existing item.
  /// ============================================================
  bool canEdit(String module) {
    return evaluate(RuntimeRequest(
      action: 'edit',
      module: module,
      capability: '$module.edit',
      policy: '$module.edit',
      permission: '$module.edit',
      featureFlag: '${module}_edit_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN PURCHASE
  /// ============================================================
  ///
  /// Check if the user can make a purchase.
  /// ============================================================
  bool canPurchase(String module) {
    return evaluate(RuntimeRequest(
      action: 'purchase',
      module: module,
      capability: '$module.purchase',
      policy: '$module.purchase',
      permission: '$module.purchase',
      featureFlag: '${module}_purchase_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN SELL
  /// ============================================================
  ///
  /// Check if the user can sell items.
  /// ============================================================
  bool canSell(String module) {
    return evaluate(RuntimeRequest(
      action: 'sell',
      module: module,
      capability: '$module.sell',
      policy: '$module.sell',
      permission: '$module.sell',
      featureFlag: '${module}_sell_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN EXPORT
  /// ============================================================
  ///
  /// Check if the user can export data.
  /// ============================================================
  bool canExport(String module) {
    return evaluate(RuntimeRequest(
      action: 'export',
      module: module,
      capability: '$module.export',
      policy: '$module.export',
      permission: '$module.export',
      featureFlag: '${module}_export_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN UPLOAD
  /// ============================================================
  ///
  /// Check if the user can upload files.
  /// ============================================================
  bool canUpload(String module) {
    return evaluate(RuntimeRequest(
      action: 'upload',
      module: module,
      capability: '$module.upload',
      policy: '$module.upload',
      permission: '$module.upload',
      featureFlag: '${module}_upload_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN VIEW ANALYTICS
  /// ============================================================
  ///
  /// Check if the user can view analytics data.
  /// ============================================================
  bool canViewAnalytics(String module) {
    return evaluate(RuntimeRequest(
      action: 'view_analytics',
      module: module,
      capability: '$module.analytics',
      policy: '$module.analytics',
      permission: '$module.analytics',
      featureFlag: '${module}_analytics_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN USE AI
  /// ============================================================
  ///
  /// Check if AI features are available for this module.
  /// ============================================================
  bool canUseAI(String module) {
    // AI check requires capability level >= 6
    if (_capabilityEngine != null) {
      final level = _capabilityEngine.getCapabilityLevel('$module.ai');
      if (level < 6) {
        return false;
      }
    }
    return evaluate(RuntimeRequest(
      action: 'use_ai',
      module: module,
      capability: '$module.ai',
      policy: '$module.ai',
      permission: '$module.ai',
      featureFlag: '${module}_ai_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN MANAGE STAFF
  /// ============================================================
  ///
  /// Check if the user can manage staff/users.
  /// ============================================================
  bool canManageStaff(String module) {
    return evaluate(RuntimeRequest(
      action: 'manage_staff',
      module: module,
      capability: '$module.staff_management',
      policy: '$module.staff_management',
      permission: '$module.manage_staff',
      featureFlag: '${module}_staff_enabled',
    )).allowed;
  }

  /// ============================================================
  /// CAN ACCESS WORKFLOW
  /// ============================================================
  ///
  /// Check if the user can access workflow features.
  /// ============================================================
  bool canAccessWorkflow(String module) {
    return evaluate(RuntimeRequest(
      action: 'access_workflow',
      module: module,
      capability: '$module.workflow',
      policy: '$module.workflow',
      permission: '$module.workflow',
      featureFlag: '${module}_workflow_enabled',
    )).allowed;
  }

  /// ============================================================
  /// EVALUATE WITH DETAILS
  /// ============================================================
  ///
  /// Convenience method that returns full RuntimeDecision.
  /// Useful when UI needs to display denial reason.
  ///
  /// Usage:
  ///   final decision = engine.evaluateExecution('workflow', 'execute');
  ///   if (decision.allowed) { ... }
  ///   else { showReason(decision.reason); }
  /// ============================================================
  RuntimeDecision evaluateExecution(String module, String action) {
    return evaluate(RuntimeRequest(
      action: action,
      module: module,
      capability: '$module.$action',
      policy: '$module.$action',
      permission: '$module.$action',
      featureFlag: '${module}_enabled',
    ));
  }

  RuntimeDecision evaluateRender(String module, String widget) {
    return evaluate(RuntimeRequest(
      action: 'render',
      module: module,
      capability: '$module.$widget',
      policy: '$module.$widget',
      permission: '$module.render',
      featureFlag: '${module}_${widget}_enabled',
    ));
  }

  RuntimeDecision evaluateNavigation(String module) {
    return evaluate(RuntimeRequest(
      action: 'navigate',
      module: module,
      capability: '$module.navigation',
      policy: '$module.navigation',
      permission: '$module.access',
      featureFlag: '${module}_enabled',
    ));
  }

  // ============================================================
  // PRIVATE METHODS
  // ============================================================

  /// Evaluate access decision for a request
  AccessDecision _evaluateAccess(RuntimeRequest request) {
    if (_accessEngine == null) {
      return const AccessDecision(
        type: AccessDecisionType.allow,
      );
    }

    return _accessEngine.evaluate(
      featureKey: request.module,
      permission: request.permission!,
      role: _context.role ?? 'guest',
      userTier: _resolveTier(),
    );
  }

  /// Evaluate feature flags for a request
  _FeatureFlagEvalResult _evaluateFeatureFlags(RuntimeRequest request) {
    final flagKey = request.featureFlag!;

    // Check runtime flags map
    final flagEnabled = _runtimeFlags[flagKey];
    if (flagEnabled == false) {
      return const _FeatureFlagEvalResult(
        allowed: false,
        reason: RuntimeReasons.featureDisabled,
        failedChecks: [RuntimeCheckCodes.FEATURE_DISABLED],
      );
    }

    // Guest check
    if (_context.isGuest) {
      return const _FeatureFlagEvalResult(
        allowed: false,
        reason: RuntimeReasons.guestNotAllowed,
        failedChecks: [RuntimeCheckCodes.GUEST_USER],
      );
    }

    // Entity check
    if (_context.entityId == null || _context.entityId!.isEmpty) {
      return const _FeatureFlagEvalResult(
        allowed: false,
        reason: RuntimeReasons.entityRequired,
        failedChecks: [RuntimeCheckCodes.ENTITY_REQUIRED],
      );
    }

    // Tier check for premium features
    if (_context.tier == 'free' && flagKey.contains('premium')) {
      return const _FeatureFlagEvalResult(
        allowed: false,
        reason: RuntimeReasons.premiumRequired,
        failedChecks: [RuntimeCheckCodes.PREMIUM_REQUIRED],
      );
    }

    return const _FeatureFlagEvalResult(
      allowed: true,
      reason: '',
      failedChecks: [],
    );
  }

  /// Resolve subscription tier from context
  dynamic _resolveTier() {
    // Map tier string to SubscriptionTier enum
    // Default to guest/free tier if not available
    return _context.tier ?? 'free';
  }
}

/// ============================================================
/// INTERNAL: FEATURE FLAG EVALUATION RESULT
/// ============================================================
class _FeatureFlagEvalResult {
  final bool allowed;
  final String reason;
  final List<String> failedChecks;

  const _FeatureFlagEvalResult({
    required this.allowed,
    required this.reason,
    required this.failedChecks,
  });
}
