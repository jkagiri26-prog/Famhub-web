/// ============================================================
/// MODULE DEGRADATION PROVIDERS — APPLICATION LAYER
/// ============================================================
///
/// PURPOSE:
/// Provides module degradation state to the runtime via Riverpod.
///
/// This is the GAP-CLOSURE for G4: "No module isolation boundary."
/// Providers expose degradation snapshots that pipeline stages and
/// UI can consume to make isolation decisions.
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/providers/ = provider wiring
///
/// ✅ PROVIDERS:
///   - moduleDegradationResolverProvider — pure degradation resolver
///   - validationRecoveryBridgeProvider — bridges validation → degradation
///   - moduleDegradationProvider — reactive degradation snapshot
///
/// ❌ Does NOT:
///   - Replace existing providers
///   - Duplicate module state management
///   - Introduce new state management patterns
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/recovery/module_degradation_resolver.dart';
import 'package:famhub_app/core/dashboard_engine/application/recovery/validation_recovery_bridge.dart';
import 'package:famhub_app/core/dashboard_engine/domain/recovery/module_degradation_state.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/dashboard_runtime_validator_provider.dart';

/// ------------------------------------------------------------
/// MODULE DEGRADATION RESOLVER PROVIDER
/// ------------------------------------------------------------
final moduleDegradationResolverProvider =
    Provider<ModuleDegradationResolver>((ref) {
  return const ModuleDegradationResolver();
});

/// ------------------------------------------------------------
/// VALIDATION RECOVERY BRIDGE PROVIDER
/// ------------------------------------------------------------
final validationRecoveryBridgeProvider =
    Provider<ValidationRecoveryBridge>((ref) {
  final resolver = ref.read(moduleDegradationResolverProvider);
  return ValidationRecoveryBridge(
    degradationResolver: resolver,
  );
});

/// ------------------------------------------------------------
/// MODULE DEGRADATION PROVIDER (STATE)
/// ------------------------------------------------------------
///
/// Maintains the current degradation snapshot.
/// Updated by the runtime when validation results are available.
///
/// This is a StateNotifierProvider so that pipeline stages can
/// emit new degradation states reactively.
/// ------------------------------------------------------------
class ModuleDegradationNotifier
    extends StateNotifier<ModuleDegradationSnapshot> {
  ModuleDegradationNotifier()
      : super(
          ModuleDegradationSnapshot(
            entries: const {},
            snapshotAt: DateTime.now(),
          ),
        );

  /// Update the degradation snapshot
  void updateSnapshot(ModuleDegradationSnapshot snapshot) {
    state = snapshot;
  }

  /// Reset all degradation entries for a list of modules to normal
  void resetModules(List<String> moduleIds) {
    final updated = Map<String, ModuleDegradationEntry>.from(state.entries);
    for (final moduleId in moduleIds) {
      final existing = updated[moduleId];
      if (existing != null && existing.level != DegradationLevel.normal) {
        updated[moduleId] = existing.copyWith(
          level: DegradationLevel.normal,
          reason: 'Manual reset',
          recoveryAttemptCount: 0,
          degradedAt: DateTime.now(),
        );
      }
    }
    state = ModuleDegradationSnapshot(
      entries: Map.unmodifiable(updated),
      snapshotAt: DateTime.now(),
    );
  }

  /// Reset all modules to normal
  void resetAll() {
    final updated = <String, ModuleDegradationEntry>{};
    for (final entry in state.entries.values) {
      updated[entry.moduleId] = entry.copyWith(
        level: DegradationLevel.normal,
        reason: 'Manual reset',
        recoveryAttemptCount: 0,
        degradedAt: DateTime.now(),
      );
    }
    state = ModuleDegradationSnapshot(
      entries: Map.unmodifiable(updated),
      snapshotAt: DateTime.now(),
    );
  }
}

final moduleDegradationProvider =
    StateNotifierProvider<ModuleDegradationNotifier,
        ModuleDegradationSnapshot>((ref) {
  return ModuleDegradationNotifier();
});

/// ------------------------------------------------------------
/// COMPUTED PROVIDERS
/// ------------------------------------------------------------

/// Whether any module is currently degraded (warning or worse)
final hasDegradedModulesProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(moduleDegradationProvider);
  return snapshot.degradedCount > 0;
});

/// List of currently degraded module IDs
final degradedModuleIdsProvider = Provider<List<String>>((ref) {
  final snapshot = ref.watch(moduleDegradationProvider);
  return snapshot.degradedModules.map((e) => e.moduleId).toList();
});

/// Whether a specific module is isolated
final isModuleIsolatedProvider =
    Provider.family<bool, String>((ref, moduleId) {
  final snapshot = ref.watch(moduleDegradationProvider);
  final entry = snapshot.forModule(moduleId);
  return entry?.level == DegradationLevel.isolated;
});

/// Whether a specific module is renderable (not isolated)
final isModuleRenderableProvider =
    Provider.family<bool, String>((ref, moduleId) {
  final snapshot = ref.watch(moduleDegradationProvider);
  final entry = snapshot.forModule(moduleId);
  return entry?.isRenderable ?? true;
});
