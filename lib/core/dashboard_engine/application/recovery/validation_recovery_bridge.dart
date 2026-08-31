// ignore: dangling_library_doc_comments
/// ============================================================
/// VALIDATION-TO-RECOVERY BRIDGE — APPLICATION LAYER
/// ============================================================
///
/// PURPOSE:
/// Bridges DashboardValidationResult output into the module
/// degradation pipeline. Transforms validation failures into
/// degradation actions that the runtime can consume.
///
/// This is the GAP-CLOSURE for G5: "Validation result not fed
/// into recovery."
///
/// FLOW:
///   DashboardRuntimeValidator.validateAll()
///       → DashboardValidationResult
///       → ValidationRecoveryBridge.translate()
///       → ModuleDegradationResolver.computeSnapshot()
///       → ModuleDegradationSnapshot
///       → Provider exposes to runtime
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/recovery/ = recovery orchestration
///
/// ✅ Used by:
///   - Pipeline stages (post-validation step)
///   - RuntimeValidator provider wrapper
///   - Diagnostics panels
///
/// ❌ Does NOT:
///   - Perform validation itself
///   - Mutate runtime state directly
///   - Replace DashboardRuntimeValidator
/// ============================================================

import 'package:famhub_app/core/dashboard_engine/application/validation/dashboard_runtime_validator.dart';
import 'package:famhub_app/core/dashboard_engine/application/validation/runtime_validation_failure.dart';
import 'package:famhub_app/core/dashboard_engine/application/recovery/module_degradation_resolver.dart';
import 'package:famhub_app/core/dashboard_engine/domain/recovery/module_degradation_state.dart';

/// ============================================================
/// VALIDATION RECOVERY BRIDGE
/// ============================================================
class ValidationRecoveryBridge {
  final ModuleDegradationResolver degradationResolver;

  const ValidationRecoveryBridge({
    required this.degradationResolver,
  });

  /// ============================================================
  /// TRANSLATE VALIDATION RESULT → DEGRADATION SNAPSHOT
  /// ============================================================
  ///
  /// Takes a DashboardValidationResult and the current degradation
  /// state, and produces an updated degradation snapshot.
  ///
  /// This is the PRIMARY ENTRY POINT for connecting validation
  /// output to the recovery/degradation system.
  /// ============================================================
  ModuleDegradationSnapshot translateToDegradation({
    required DashboardValidationResult validationResult,
    required ModuleDegradationSnapshot currentSnapshot,
    required Set<String> allModuleIds,
  }) {
    // Group failures by module
    final failuresByModule = <String, List<RuntimeValidationFailure>>{};
    for (final nodeResult in validationResult.nodeResults) {
      if (!nodeResult.isValid && nodeResult.failure != null) {
        final moduleKey = nodeResult.node.moduleKey;
        failuresByModule.putIfAbsent(moduleKey, () => []);
        failuresByModule[moduleKey]!.add(nodeResult.failure!);
      }
    }

    return degradationResolver.computeSnapshot(
      currentEntries: currentSnapshot.entries,
      failuresByModule: failuresByModule,
      allModuleIds: allModuleIds,
    );
  }

  /// ============================================================
  /// GET ALL MODULE IDS FROM REGISTRY
  /// ============================================================
  ///
  /// Convenience helper to get the full set of known module IDs
  /// from the static module registry.
  /// ============================================================
  Set<String> getAllModuleIds() {
    return {
      for (final def
          in _getAllModuleDefinitions())
        def.moduleId,
    };
  }

  /// Static list of all module IDs (cache-friendly, pure lookup)
  static List<_ModuleIdRef> _getAllModuleDefinitions() {
    // Reference the static registry — we only need moduleId values
    // Import moved here to keep the bridge dependency-light
    return const [
      _ModuleIdRef('farm_management'),
      _ModuleIdRef('marketplace'),
      _ModuleIdRef('analytics'),
      _ModuleIdRef('finance'),
      _ModuleIdRef('logistics'),
      _ModuleIdRef('traceability'),
      _ModuleIdRef('carbon_credit'),
      _ModuleIdRef('knowledge'),
      _ModuleIdRef('agribusiness'),
      _ModuleIdRef('opportunities'),
      _ModuleIdRef('extension_services'),
      _ModuleIdRef('agri_connect'),
      _ModuleIdRef('agri_tech_lab'),
      _ModuleIdRef('referral_hub'),
      _ModuleIdRef('profile'),
      _ModuleIdRef('admin_console'),
    ];
  }
}

/// Lightweight module ID reference for lookup helper
class _ModuleIdRef {
  final String moduleId;
  const _ModuleIdRef(this.moduleId);
}
