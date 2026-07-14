/// ============================================================
/// RUNTIME DECISION PROVIDERS — RIVERPOD BRIDGE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/runtime_decision/application/ = application layer
///
/// These Riverpod providers expose the RuntimeDecisionEngine
/// and convenience providers to the entire application.
///
/// ✅ RESPONSIBILITIES:
///   - Expose RuntimeDecisionEngine through Riverpod
///   - Provide convenience providers for common checks
///   - Auto-invalidate on context/capability/policy changes
///
/// ❌ Does NOT:
///   - Perform UI rendering
///   - Execute business logic
///   - Import Flutter widgets
///
/// ✅ USAGE:
///   Widgets use these providers instead of calling
///   CapabilityEngine, PolicyEngine, AccessEngine, or
///   RuntimeFeatureFlags directly.
///
///   Before:
///     if (engine.hasCapability(...) && policy.isAllowed(...))
///
///   After:
///     if (ref.watch(canRenderProvider(('module', 'widget')))
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/runtime_decision/domain/runtime_request.dart';
import 'package:famhub_app/core/runtime_decision/domain/runtime_decision.dart';
import 'package:famhub_app/core/runtime_decision/application/runtime_decision_engine.dart';
import 'package:famhub_app/core/capabilities/application/capability_engine.dart';
import 'package:famhub_app/core/capabilities/application/capability_provider.dart';
import 'package:famhub_app/core/policies/application/policy_engine.dart';
import 'package:famhub_app/core/policies/application/policy_provider.dart';
import 'package:famhub_app/core/access/application/providers/access_policy_provider.dart';
import 'package:famhub_app/core/access/access_decision_engine.dart';
import 'package:famhub_app/core/feature_flags/application/providers/runtime_flags_provider.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';

/// ============================================================
/// PROVIDER: RUNTIME DECISION ENGINE
/// ============================================================
///
/// The main runtime decision engine provider. Combines all
/// governance engines into a single evaluation point.
///
/// Rebuilds whenever any dependency changes:
///   - Capability profile
///   - Policy
///   - Access policy
///   - Runtime flags
///   - Entity context
/// ============================================================
final runtimeDecisionEngineProvider =
    Provider<RuntimeDecisionEngine?>((ref) {
  // Watch all dependency providers
  final capabilityEngine = ref.watch(capabilityEngineProvider);
  final policyEngine = ref.watch(policyEngineProvider);
  final accessPolicyAsync = ref.watch(accessPolicyProvider);
  final runtimeFlags = ref.watch(runtimeFlagsProvider);
  final context = ref.watch(contextProvider);

  // Build AccessDecisionEngine if access policy is available
  AccessDecisionEngine? accessEngine;
  accessPolicyAsync.whenOrNull(
    data: (data) {
      // AccessDecisionEngine wraps a Ref, so we create it once
      // and it caches internally
      accessEngine = AccessDecisionEngine(ref);
    },
  );

  // If no capability engine is available, return null
  if (capabilityEngine == null) return null;

  return RuntimeDecisionEngine(
    capabilityEngine: capabilityEngine,
    policyEngine: policyEngine,
    accessEngine: accessEngine,
    context: context,
    runtimeFlags: runtimeFlags,
  );
});

/// ============================================================
/// PROVIDER: RUNTIME DECISION (FAMILY)
/// ============================================================
///
/// Evaluates a single RuntimeRequest through the decision engine.
///
/// Usage:
///   final decision = ref.watch(runtimeDecisionProvider(
///     RuntimeRequest(action: 'execute', module: 'workflow', ...)
///   ));
/// ============================================================
final runtimeDecisionProvider =
    Provider.family<RuntimeDecision, RuntimeRequest>((ref, request) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) {
    return const RuntimeDecision.denied(
      reason: 'Runtime Decision Engine not available',
      source: 'Runtime Decision Engine',
      failedChecks: ['ENGINE_NOT_AVAILABLE'],
    );
  }
  return engine.evaluate(request);
});

/// ============================================================
/// PROVIDER: CAN RENDER
/// ============================================================
///
/// Convenience provider for rendering checks.
///
/// Usage:
///   final canShow = ref.watch(canRenderProvider(('marketplace', 'kpi_card')));
/// ============================================================
final canRenderProvider =
    Provider.family<bool, (String module, String widget)>((ref, params) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canRender(params.$1, params.$2);
});

/// ============================================================
/// PROVIDER: CAN EXECUTE
/// ============================================================
///
/// Convenience provider for execution checks.
///
/// Usage:
///   final canExec = ref.watch(canExecuteProvider(('workflow', 'execute')));
/// ============================================================
final canExecuteProvider =
    Provider.family<bool, (String module, String action)>((ref, params) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canExecute(params.$1, params.$2);
});

/// ============================================================
/// PROVIDER: CAN NAVIGATE
/// ============================================================
///
/// Convenience provider for navigation checks.
///
/// Usage:
///   final canNav = ref.watch(canNavigateProvider('marketplace'));
/// ============================================================
final canNavigateProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canNavigate(module);
});

/// ============================================================
/// PROVIDER: CAN APPROVE
/// ============================================================
///
/// Convenience provider for approval checks.
///
/// Usage:
///   final canApp = ref.watch(canApproveProvider('workflow'));
/// ============================================================
final canApproveProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canApprove(module);
});

/// ============================================================
/// PROVIDER: CAN DELETE
/// ============================================================
///
/// Convenience provider for delete checks.
///
/// Usage:
///   final canDel = ref.watch(canDeleteProvider('marketplace'));
/// ============================================================
final canDeleteProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canDelete(module);
});

/// ============================================================
/// PROVIDER: CAN CREATE
/// ============================================================
///
/// Convenience provider for create checks.
///
/// Usage:
///   final canCreate = ref.watch(canCreateProvider('marketplace'));
/// ============================================================
final canCreateProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canCreate(module);
});

/// ============================================================
/// PROVIDER: CAN EDIT
/// ============================================================
///
/// Convenience provider for edit checks.
///
/// Usage:
///   final canEdit = ref.watch(canEditProvider('marketplace'));
/// ============================================================
final canEditProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canEdit(module);
});

/// ============================================================
/// PROVIDER: CAN PURCHASE
/// ============================================================
///
/// Convenience provider for purchase checks.
///
/// Usage:
///   final canBuy = ref.watch(canPurchaseProvider('marketplace'));
/// ============================================================
final canPurchaseProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canPurchase(module);
});

/// ============================================================
/// PROVIDER: CAN SELL
/// ============================================================
///
/// Convenience provider for sell checks.
///
/// Usage:
///   final canSell = ref.watch(canSellProvider('marketplace'));
/// ============================================================
final canSellProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canSell(module);
});

/// ============================================================
/// PROVIDER: CAN EXPORT
/// ============================================================
///
/// Convenience provider for export checks.
///
/// Usage:
///   final canExport = ref.watch(canExportProvider('traceability'));
/// ============================================================
final canExportProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canExport(module);
});

/// ============================================================
/// PROVIDER: CAN UPLOAD
/// ============================================================
///
/// Convenience provider for upload checks.
///
/// Usage:
///   final canUpload = ref.watch(canUploadProvider('marketplace'));
/// ============================================================
final canUploadProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canUpload(module);
});

/// ============================================================
/// PROVIDER: CAN VIEW ANALYTICS
/// ============================================================
///
/// Convenience provider for analytics visibility checks.
///
/// Usage:
///   final canViewAnalytics = ref.watch(canViewAnalyticsProvider('marketplace'));
/// ============================================================
final canViewAnalyticsProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canViewAnalytics(module);
});

/// ============================================================
/// PROVIDER: CAN USE AI
/// ============================================================
///
/// Convenience provider for AI feature checks.
///
/// Usage:
///   final canUseAI = ref.watch(canUseAIProvider('marketplace'));
/// ============================================================
final canUseAIProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canUseAI(module);
});

/// ============================================================
/// PROVIDER: CAN MANAGE STAFF
/// ============================================================
///
/// Convenience provider for staff management checks.
///
/// Usage:
///   final canManageStaff = ref.watch(canManageStaffProvider('admin'));
/// ============================================================
final canManageStaffProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canManageStaff(module);
});

/// ============================================================
/// PROVIDER: CAN ACCESS WORKFLOW
/// ============================================================
///
/// Convenience provider for workflow access checks.
///
/// Usage:
///   final canAccessWorkflow = ref.watch(canAccessWorkflowProvider('traceability'));
/// ============================================================
final canAccessWorkflowProvider = Provider.family<bool, String>((ref, module) {
  final engine = ref.watch(runtimeDecisionEngineProvider);
  if (engine == null) return false;
  return engine.canAccessWorkflow(module);
});
