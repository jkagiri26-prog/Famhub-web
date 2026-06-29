import 'package:famhub_app/system/registry/dependency_registry.dart';
import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/domain/models/composition_metrics.dart';

/// ============================================================
/// DEPENDENCY RESOLVER (COMPOSITION ENGINE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/engine/ = composition engine layer
///
/// ✅ Responsibilities:
///   - Resolve module dependency constraints
///   - Remove modules whose required dependencies are missing
///   - Report dependency failures for observability
///   - Pure logic — no side effects, no I/O
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Reads static DependencyRegistry (system/registry/)
///   - Works on RuntimeModules after access filtering
///   - No UI references, no providers
///
/// ⚠️ KEY RULE:
///   - If module B depends on module A (required)
///   - And A is not in the enabled/accessible list
///   - Then B is automatically removed
///
/// Example:
///   CarbonCredit depends on FarmManagement
///   FarmManagement is disabled
///   → CarbonCredit is removed
/// ============================================================
class DependencyResolver {
  /// ============================================================
  /// RESOLVE DEPENDENCIES
  /// ============================================================
  ///
  /// Iteratively removes modules with unsatisfied required dependencies.
  /// Repeats until stable (a removed module might break another).
  ///
  /// [modules] - List of RuntimeModules after access filtering
  /// [metrics] - Optional metrics collector for observability
  /// Returns a stable list with only modules whose dependencies are met
  /// ============================================================
  List<RuntimeModule> resolveDependencies(
    List<RuntimeModule> modules, {
    CompositionMetricsCollector? metrics,
  }) {
    // Build a mutable set of enabled module IDs
    final enabledIds = <String>{};
    for (final m in modules) {
      if (m.isEnabled) {
        enabledIds.add(m.moduleId);
      }
    }

    final result = <RuntimeModule>[];
    bool changed;

    // Iteratively resolve: when a module is removed due to missing dep,
    // other modules depending on it may also need removal
    do {
      changed = false;
      result.clear();

      for (final module in modules) {
        if (!module.isEnabled) continue;

        // Check if all required dependencies are satisfied
        final deps = DependencyRegistry.requiredDependenciesOf(module.moduleId);
        bool depsSatisfied = true;

        for (final dep in deps) {
          if (!enabledIds.contains(dep.toModuleId)) {
            depsSatisfied = false;
            break;
          }
        }

        if (depsSatisfied) {
          result.add(module);
        } else {
          // Module removed due to missing dependency
          enabledIds.remove(module.moduleId);
          changed = true;
          metrics?.recordDependencyFailure();

          debugLog(
            'DependencyResolver: Removed "${module.moduleId}" '
            '(missing required dependency)',
          );
        }
      }

      modules = result;
    } while (changed);

    return result;
  }

  /// ============================================================
  /// CHECK DEPENDENCY SATISFACTION (FOR A SINGLE MODULE)
  /// ============================================================
  ///
  /// Returns true if all required dependencies of [moduleId]
  /// are present in [enabledModuleIds].
  /// ============================================================
  bool areDependenciesSatisfied(
    String moduleId,
    Set<String> enabledModuleIds,
  ) {
    final deps = DependencyRegistry.requiredDependenciesOf(moduleId);
    for (final dep in deps) {
      if (!enabledModuleIds.contains(dep.toModuleId)) {
        return false;
      }
    }
    return true;
  }

  /// ============================================================
  /// GET UNSATISFIED DEPENDENCIES
  /// ============================================================
  ///
  /// Returns a list of dependency module IDs that are required
  /// but not present in [enabledModuleIds].
  /// ============================================================
  List<String> getUnsatisfiedDependencies(
    String moduleId,
    Set<String> enabledModuleIds,
  ) {
    final result = <String>[];
    final deps = DependencyRegistry.requiredDependenciesOf(moduleId);
    for (final dep in deps) {
      if (!enabledModuleIds.contains(dep.toModuleId)) {
        result.add(dep.toModuleId);
      }
    }
    return result;
  }

  /// ============================================================
  /// DEBUG LOGGING
  /// ============================================================
  static void debugLog(String message) {
    // ignore: avoid_print
    print('[DependencyResolver] $message');
  }
}
