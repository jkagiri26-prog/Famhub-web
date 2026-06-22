import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/recovery/module_degradation_resolver.dart';
import 'package:famhub_app/core/dashboard_engine/application/recovery/validation_recovery_bridge.dart';
import 'package:famhub_app/core/dashboard_engine/domain/recovery/module_degradation_state.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/dashboard_runtime_validator_provider.dart';

/// ============================================================
/// MODULE DEGRADATION RESOLVER PROVIDER
/// ============================================================
final moduleDegradationResolverProvider =
    Provider<ModuleDegradationResolver>((ref) {
  return const ModuleDegradationResolver();
});

/// ============================================================
/// VALIDATION RECOVERY BRIDGE PROVIDER
/// ============================================================
final validationRecoveryBridgeProvider =
    Provider<ValidationRecoveryBridge>((ref) {
  final resolver = ref.read(moduleDegradationResolverProvider);
  return ValidationRecoveryBridge(
    degradationResolver: resolver,
  );
});

/// ============================================================
/// MODULE DEGRADATION NOTIFIER (RIVERPOD 3)
/// ============================================================
class ModuleDegradationNotifier
    extends Notifier<ModuleDegradationSnapshot> {
  @override
  ModuleDegradationSnapshot build() {
    return ModuleDegradationSnapshot(
      entries: const {},
      snapshotAt: DateTime.now(),
    );
  }

  /// Update full snapshot
  void updateSnapshot(ModuleDegradationSnapshot snapshot) {
    state = snapshot;
  }

  /// Reset selected modules
  void resetModules(List<String> moduleIds) {
    final updated =
        Map<String, ModuleDegradationEntry>.from(state.entries);

    for (final moduleId in moduleIds) {
      final existing = updated[moduleId];

      if (existing != null &&
          existing.level != DegradationLevel.normal) {
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

  /// Reset everything
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

/// ============================================================
/// PROVIDER (RIVERPOD 3 STANDARD)
/// ============================================================
final moduleDegradationProvider =
    NotifierProvider<ModuleDegradationNotifier,
        ModuleDegradationSnapshot>(
  ModuleDegradationNotifier.new,
);

/// ============================================================
/// COMPUTED PROVIDERS (UNCHANGED - GOOD DESIGN)
/// ============================================================

final hasDegradedModulesProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(moduleDegradationProvider);
  return snapshot.degradedCount > 0;
});

final degradedModuleIdsProvider = Provider<List<String>>((ref) {
  final snapshot = ref.watch(moduleDegradationProvider);
  return snapshot.degradedModules.map((e) => e.moduleId).toList();
});

final isModuleIsolatedProvider =
    Provider.family<bool, String>((ref, moduleId) {
  final snapshot = ref.watch(moduleDegradationProvider);
  final entry = snapshot.forModule(moduleId);
  return entry?.level == DegradationLevel.isolated;
});

final isModuleRenderableProvider =
    Provider.family<bool, String>((ref, moduleId) {
  final snapshot = ref.watch(moduleDegradationProvider);
  final entry = snapshot.forModule(moduleId);
  return entry?.isRenderable ?? true;
});