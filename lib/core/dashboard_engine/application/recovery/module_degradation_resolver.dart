/// ============================================================
/// MODULE DEGRADATION RESOLVER — APPLICATION LAYER
/// ============================================================
///
/// PURPOSE:
/// Resolves per-module degradation decisions based on validation
/// failures, dependency failures, and recovery policies.
///
/// This is a PURE LOGIC layer — no UI, no providers, no I/O.
///
/// RESPONSIBILITIES:
/// - Evaluate validation failures → degradation level
/// - Cascade degradation to dependent modules (G3)
/// - Determine whether auto-recovery should activate
/// - Compute degradation snapshots
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/recovery/ = recovery orchestration
///
/// ✅ USAGE:
///   Used by RuntimeValidator, PipelineStages, and Providers.
///   Pure function calls — deterministic, testable.
/// ============================================================

import 'package:famhub_app/core/dashboard_engine/domain/recovery/module_degradation_state.dart';
import 'package:famhub_app/core/dashboard_engine/application/validation/runtime_validation_failure.dart';
import 'package:famhub_app/system/registry/dependency_registry.dart';

/// Configuration for degradation resolution
class DegradationConfig {
  /// How many failures before a module is degraded
  final int failuresBeforeDegradation;

  /// How many failures before a module is isolated
  final int failuresBeforeIsolation;

  /// Maximum auto-recovery attempts before requiring manual intervention
  final int maxAutoRecoveryAttempts;

  /// How long (in seconds) before a module auto-recovers after degradation
  final int autoRecoveryCooldownSeconds;

  /// Whether cascading degradation is enabled
  final bool enableCascadeDegradation;

  const DegradationConfig({
    this.failuresBeforeDegradation = 3,
    this.failuresBeforeIsolation = 10,
    this.maxAutoRecoveryAttempts = 5,
    this.autoRecoveryCooldownSeconds = 30,
    this.enableCascadeDegradation = true,
  });
}

/// ============================================================
/// MODULE DEGRADATION RESOLVER
/// ============================================================
class ModuleDegradationResolver {
  final DegradationConfig config;

  const ModuleDegradationResolver({
    this.config = const DegradationConfig(),
  });

  /// ============================================================
  /// EVALUATE A SINGLE VALIDATION FAILURE
  /// ============================================================
  ///
  /// Maps a RuntimeValidationFailure to a degradation level.
  ///
  /// Mapping rules:
  /// - moduleNotFound → isolated (critical infrastructure missing)
  /// - routeNotFound → degraded (config issue)
  /// - widgetNotFound → warning (missing UI, fallback available)
  /// - dependencyUnsatisfied → isolated (cannot function without dep)
  /// - featureDisabled → warning (soft gate)
  /// - accessDenied → warning (user-specific)
  /// - subscriptionNotAllowed → warning (tier-specific)
  /// - maintenanceModeOn → warning (temporary)
  /// ============================================================
  DegradationLevel evaluateFailureLevel(
    RuntimeValidationFailure failure,
  ) {
    switch (failure.type) {
      case ValidationFailureType.moduleNotFound:
        return DegradationLevel.isolated;
      case ValidationFailureType.dependencyUnsatisfied:
        return DegradationLevel.isolated;
      case ValidationFailureType.routeNotFound:
        return DegradationLevel.degraded;
      case ValidationFailureType.widgetNotFound:
        return DegradationLevel.warning;
      case ValidationFailureType.featureDisabled:
        return DegradationLevel.warning;
      case ValidationFailureType.accessDenied:
        return DegradationLevel.warning;
      case ValidationFailureType.subscriptionNotAllowed:
        return DegradationLevel.warning;
      case ValidationFailureType.maintenanceModeOn:
        return DegradationLevel.warning;
    }
  }

  /// ============================================================
  /// RESOLVE DEGRADATION FOR A MODULE
  /// ============================================================
  ///
  /// Given current degradation entry + new failures, determine
  /// the next degradation level.
  ///
  /// This handles:
  /// - Escalation (normal → warning → degraded → isolated)
  /// - De-escalation (recovery)
  /// - Sticky isolation (no auto-recovery from isolated without manual reset)
  /// ============================================================
  ModuleDegradationEntry resolveDegradation({
    required ModuleDegradationEntry current,
    required List<RuntimeValidationFailure> newFailures,
    required bool isDependencyDegraded,
  }) {
    // If already isolated and auto-recovery disabled, stay isolated
    if (current.level == DegradationLevel.isolated &&
        !current.autoRecoveryEnabled) {
      return current;
    }

    // If dependency is degraded, cascade if enabled
    if (isDependencyDegraded && config.enableCascadeDegradation) {
      return _cascadeDegradation(current);
    }

    // No new failures — attempt recovery
    if (newFailures.isEmpty && current.requiresAttention) {
      return _attemptRecovery(current);
    }

    // No new failures and already healthy — no change
    if (newFailures.isEmpty) {
      return current;
    }

    // Evaluate the worst failure level among new failures
    DegradationLevel worstLevel = DegradationLevel.normal;
    for (final failure in newFailures) {
      final level = evaluateFailureLevel(failure);
      if (level.index > worstLevel.index) {
        worstLevel = level;
      }
    }

    // Calculate cumulative failure count
    final cumulativeFailures =
        current.recoveryAttemptCount + newFailures.length;

    // Escalate based on cumulative failures and worst failure level
    DegradationLevel nextLevel;
    if (worstLevel == DegradationLevel.isolated ||
        cumulativeFailures >= config.failuresBeforeIsolation) {
      nextLevel = DegradationLevel.isolated;
    } else if (worstLevel == DegradationLevel.degraded ||
        cumulativeFailures >= config.failuresBeforeDegradation) {
      nextLevel = DegradationLevel.degraded;
    } else if (worstLevel == DegradationLevel.warning) {
      nextLevel = DegradationLevel.warning;
    } else {
      nextLevel = current.level;
    }

    // Determine the failure reason
    final reason = newFailures.isNotEmpty
        ? _summarizeFailures(newFailures)
        : current.reason;

    // Disable auto-recovery if threshold exceeded
    final canAutoRecover =
        cumulativeFailures < config.maxAutoRecoveryAttempts;

    return current.copyWith(
      level: nextLevel,
      reason: reason,
      recoveryAttemptCount: cumulativeFailures,
      autoRecoveryEnabled: canAutoRecover,
      failureType: newFailures.isNotEmpty
          ? newFailures.first.type.name
          : current.failureType,
      triggeringWidgetKey: newFailures.isNotEmpty
          ? newFailures.first.widgetKey
          : current.triggeringWidgetKey,
      degradedAt: nextLevel != current.level
          ? DateTime.now()
          : current.degradedAt,
    );
  }

  /// ============================================================
  /// CASCADE DEGRADATION TO DEPENDENTS
  /// ============================================================
  ///
  /// When a required dependency fails, cascade degradation to
  /// all modules that depend on it.
  ///
  /// This prevents downstream modules from attempting to function
  /// without their required dependencies.
  /// ============================================================
  List<String> resolveDependentDegradation(String moduleId) {
    final dependents = DependencyRegistry.dependentsOf(moduleId);
    return dependents
        .where((d) => d.isRequired)
        .map((d) => d.fromModuleId)
        .toList();
  }

  /// ============================================================
  /// COMPUTE DEGRADATION SNAPSHOT
  /// ============================================================
  ///
  /// Given current degradation map + validation results, produce
  /// an updated degradation snapshot.
  /// ============================================================
  ModuleDegradationSnapshot computeSnapshot({
    required Map<String, ModuleDegradationEntry> currentEntries,
    required Map<String, List<RuntimeValidationFailure>> failuresByModule,
    required Set<String> allModuleIds,
  }) {
    final updatedEntries = <String, ModuleDegradationEntry>{};
    final cascadeTargets = <String>{};

    // Process each module
    for (final moduleId in allModuleIds) {
      final current = currentEntries[moduleId] ??
          ModuleDegradationEntry(
            moduleId: moduleId,
            level: DegradationLevel.normal,
            degradedAt: DateTime.now(),
            reason: 'Initial state',
          );

      final moduleFailures = failuresByModule[moduleId] ?? [];

      // Check if any dependency is degraded
      final deps = DependencyRegistry.requiredDependenciesOf(moduleId);
      final isDepDegraded = deps.any((dep) {
        final depEntry = currentEntries[dep.toModuleId];
        return depEntry != null && depEntry.level != DegradationLevel.normal;
      });

      final resolved = resolveDegradation(
        current: current,
        newFailures: moduleFailures,
        isDependencyDegraded: isDepDegraded,
      );

      updatedEntries[moduleId] = resolved;

      // Track cascade targets
      if (config.enableCascadeDegradation &&
          resolved.level == DegradationLevel.isolated) {
        cascadeTargets.addAll(
          resolveDependentDegradation(moduleId),
        );
      }
    }

    // Process cascade degradation for dependents
    for (final targetId in cascadeTargets) {
      final current = updatedEntries[targetId] ??
          ModuleDegradationEntry(
            moduleId: targetId,
            level: DegradationLevel.normal,
            degradedAt: DateTime.now(),
            reason: 'Initial state',
          );

      // Only cascade if not already more strict
      if (current.level.index < DegradationLevel.degraded.index) {
        updatedEntries[targetId] = current.copyWith(
          level: DegradationLevel.degraded,
          reason:
              'Cascaded degradation due to required dependency failure',
          degradedAt: DateTime.now(),
        );
      }
    }

    return ModuleDegradationSnapshot(
      entries: Map.unmodifiable(updatedEntries),
      snapshotAt: DateTime.now(),
    );
  }

  // ─── PRIVATE HELPERS ──────────────────────────────────────────

  ModuleDegradationEntry _cascadeDegradation(
    ModuleDegradationEntry current,
  ) {
    if (current.level.index >= DegradationLevel.degraded.index) {
      return current;
    }

    return current.copyWith(
      level: DegradationLevel.degraded,
      reason:
          'Degraded due to required dependency failure (cascade)',
      degradedAt: DateTime.now(),
    );
  }

  ModuleDegradationEntry _attemptRecovery(
    ModuleDegradationEntry current,
  ) {
    // Can only recover if auto-recovery is enabled
    if (!current.autoRecoveryEnabled) {
      return current;
    }

    // Can't auto-recover if isolated (requires manual intervention)
    if (current.level == DegradationLevel.isolated) {
      return current;
    }

    // Check cooldown
    final timeSinceDegradation =
        DateTime.now().difference(current.degradedAt);
    if (timeSinceDegradation.inSeconds <
        config.autoRecoveryCooldownSeconds) {
      return current;
    }

    // De-escalate one level
    DegradationLevel recoveredLevel;
    switch (current.level) {
      case DegradationLevel.degraded:
        recoveredLevel = DegradationLevel.warning;
      case DegradationLevel.warning:
        recoveredLevel = DegradationLevel.normal;
      default:
        recoveredLevel = current.level;
    }

    return current.copyWith(
      level: recoveredLevel,
      reason: recoveredLevel == DegradationLevel.normal
          ? 'Auto-recovered after cooldown'
          : 'Partially recovered (${current.level} → $recoveredLevel)',
      recoveryAttemptCount: 0,
      degradedAt:
          recoveredLevel != current.level ? DateTime.now() : current.degradedAt,
    );
  }

  String _summarizeFailures(List<RuntimeValidationFailure> failures) {
    if (failures.length == 1) {
      return failures.first.message;
    }
    final types = failures.map((f) => f.type.name).toSet().join(', ');
    return '$types (${failures.length} failures)';
  }
}
