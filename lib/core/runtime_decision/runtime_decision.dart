/// ============================================================
/// RUNTIME DECISION MODULE — BARREL EXPORT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/runtime_decision/ = runtime decision module root
///
/// The Runtime Decision Engine is the SINGLE evaluation engine
/// that combines every governance layer into one final decision.
///
/// No widget, provider, service, or workflow should ever need
/// to ask capability, policy, access, or feature flag individually.
/// Instead, they ask ONE engine.
///
/// ✅ ARCHITECTURE:
///   Entity Context
///        ↓
///   Capability Engine    ← Layer 1
///        ↓
///   Policy Engine        ← Layer 2
///        ↓
///   Access Engine        ← Layer 3
///        ↓
///   Runtime Feature Flags ← Layer 4
///        ↓
///   Runtime Decision Engine
///        ↓
///   Composition
///        ↓
///   Shell
///
/// ✅ USAGE:
///   final decision = runtimeDecisionEngine.evaluate(RuntimeRequest(
///     action: 'execute',
///     module: 'workflow',
///     capability: 'workflow.execution',
///     policy: 'workflow.execution',
///     permission: 'workflow.execute',
///     featureFlag: 'workflow_enabled',
///   ));
///
///   if (!decision.allowed) {
///     print('Denied: ${decision.reason} (Source: ${decision.source})');
///   }
/// ============================================================
library;

// ── Domain Models ──
export 'domain/runtime_decision.dart';
export 'domain/runtime_reason.dart';
export 'domain/runtime_request.dart';

// ── Application Layer ──
export 'application/runtime_decision_engine.dart';
export 'application/runtime_decision_provider.dart';

// ── Composition Layer ──
export 'composition/runtime_decision_bridge.dart';
