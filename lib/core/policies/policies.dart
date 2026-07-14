/// ============================================================
/// POLICY FRAMEWORK — BARREL EXPORT
/// ============================================================
///
/// Single import point for all policy framework components.
///
/// Usage:
///   import 'package:famhub_app/core/policies/policies.dart';
///
/// Then:
///   ref.watch(policyBooleanProvider(Policies.workflowExecution))
///   ref.watch(policyEngineProvider)?.isAllowed(Policies.traceability)
///   ref.watch(policyNumberProvider(Policies.maxImageUpload))
///   PolicyRuleRegistry.get('workflow.execution')
///
/// Dependency direction:
///   Presentation
///     ↓
///   Application
///     ↓
///   Domain
///     ↓
///   Infrastructure (repository only)
///
/// No Flutter imports inside domain.
/// No Riverpod inside domain.
/// No UI inside infrastructure.
/// ============================================================
library;

// ── Domain ──
export 'domain/policy.dart';
export 'domain/policy_rule.dart';
export 'domain/effective_policy.dart';

// ── Registry ──
export 'registry/policy_rule_registry.dart';

// ── Application ──
export 'application/policy_engine.dart';
export 'application/policy_provider.dart';
export 'application/effective_policy_provider.dart';

// ── Infrastructure ──
export 'infrastructure/policy_repository.dart';
export 'infrastructure/supabase_policy_repository.dart';

// ── Composition Bridge ──
export 'composition/policy_composition_bridge.dart';
export 'composition/policy_composition_providers.dart';

// ── Bootstrap ──
export 'bootstrap/policy_bootstrap.dart';
