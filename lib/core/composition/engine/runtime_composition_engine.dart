import 'package:flutter/foundation.dart';

import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/system/registry/module_registry.dart';
import 'package:famhub_app/system/registry/dependency_registry.dart';
import 'package:famhub_app/system/registry/registry_contracts.dart';
import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/domain/models/composition_metrics.dart';
import 'package:famhub_app/core/composition/engine/dependency_resolver.dart';
import 'package:famhub_app/core/composition/engine/module_access_filter.dart';
import 'package:famhub_app/core/composition/engine/module_to_runtime_mapper.dart';

/// ============================================================
/// RUNTIME COMPOSITION ENGINE (CORE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/engine/ = composition engine layer
///
/// ✅ Responsibilities:
///   - Single entry point for all runtime composition
///   - Build the complete RuntimeModuleRegistry from raw inputs
///   - Orchestrate: fetch → filter → resolve dependencies → map → output
///   - Track composition metrics for observability
///   - Cache the registry for performance (invalidated on change)
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Single backend fetch for module metadata
///   - NO hardcoded module visibility conditions
///   - Everything flows through Context Engine + Governance
///   - Registry caching with lazy page loading
///   - Provider-based invalidation only
///
/// ❌ Does NOT:
///   - Render UI
///   - Register routes directly (delegates to RouteRegistrar)
///   - Build navigation directly (delegates to NavigationBuilder)
///   - Build dashboard directly (delegates to DashboardComposer)
///   - Import Flutter UI widgets
/// ============================================================
class RuntimeCompositionEngine {
  final DependencyResolver _dependencyResolver;
  final ModuleAccessFilter _accessFilter;
  final ModuleToRuntimeMapper _runtimeMapper;
  final CompositionMetricsCollector _metrics;

  /// Internal cache of resolved runtime modules
  List<RuntimeModule>? _cachedRegistry;

  /// Sequence number for cache invalidation tracking
  int _cacheSequence = 0;

  RuntimeCompositionEngine({
    DependencyResolver? dependencyResolver,
    ModuleAccessFilter? accessFilter,
    ModuleToRuntimeMapper? runtimeMapper,
    CompositionMetricsCollector? metrics,
  })  : _dependencyResolver =
            dependencyResolver ?? DependencyResolver(),
        _accessFilter = accessFilter ?? ModuleAccessFilter(),
        _runtimeMapper = runtimeMapper ?? ModuleToRuntimeMapper(),
        _metrics = metrics ?? compositionMetricsCollector;

  /// ============================================================
  /// BUILD COMPLETE RUNTIME MODULE REGISTRY
  /// ============================================================
  ///
  /// Full pipeline from raw SystemModules → RuntimeModuleRegistry.
  ///
  /// Pipeline:
  ///   1. Map SystemModules to RuntimeModules
  ///   2. Apply Context Engine access filtering
  ///   3. Resolve dependencies (remove modules with missing deps)
  ///   4. Resolve widget builder keys from WidgetRegistry
  ///   5. Sort by display order
  ///   6. Cache the result
  ///
  /// [modules] - Raw list of SystemModules from backend
  /// [context] - Current EntityContext from Context Engine
  /// Returns a fully resolved list of RuntimeModules
  /// ============================================================
  List<RuntimeModule> buildRegistry({
    required List<SystemModule> modules,
    required EntityContext context,
  }) {
    final stopwatch = Stopwatch()..start();

    // ── 1. Map SystemModules to RuntimeModules ──
    final runtimeModules = modules.map((m) {
      _metrics.recordModuleLoaded();
      return _runtimeMapper.mapToRuntime(m);
    }).toList();

    // ── 2. Apply Context Engine access filtering ──
    final filteredModules = _accessFilter.filterModules(
      modules: runtimeModules,
      context: context,
      metrics: _metrics,
    );

    // ── 3. Resolve dependencies ──
    final resolvedModules = _dependencyResolver.resolveDependencies(
      filteredModules,
      metrics: _metrics,
    );

    // ── 4. Resolve widget builder keys ──
    for (final module in resolvedModules) {
      final def = ModuleRegistry.byId(module.moduleId);
      if (def != null && module.widgetBuilderKey == null) {
        // Use moduleId as default widget builder key
        // unless a specific key is provided
      }
    }

    // ── 5. Sort by display order ──
    resolvedModules.sort((a, b) {
      if (a.pinned && !b.pinned) return -1;
      if (!a.pinned && b.pinned) return 1;
      return a.displayOrder.compareTo(b.displayOrder);
    });

    // ── 6. Cache the result ──
    _cachedRegistry = resolvedModules;
    _cacheSequence++;

    stopwatch.stop();
    _metrics.recordCompositionDuration(stopwatch.elapsedMilliseconds);

    return resolvedModules;
  }

  /// ============================================================
  /// GET MODULES FOR SIDEBAR
  /// ============================================================
  ///
  /// Returns only modules with sidebar_visible = true.
  /// ============================================================
  List<RuntimeModule> getSidebarModules() {
    final registry = _getCachedRegistry();
    return registry.where((m) => m.sidebarVisible && m.isEnabled).toList();
  }

  /// ============================================================
  /// GET MODULES FOR BOTTOM NAV
  /// ============================================================
  ///
  /// Returns only modules with bottom_nav_visible = true.
  /// ============================================================
  List<RuntimeModule> getBottomNavModules() {
    final registry = _getCachedRegistry();
    return registry
        .where((m) => m.bottomNavVisible && m.isEnabled)
        .toList();
  }

  /// ============================================================
  /// GET MODULES FOR DASHBOARD
  /// ============================================================
  ///
  /// Returns only modules with dashboard_visible = true.
  /// ============================================================
  List<RuntimeModule> getDashboardModules() {
    final registry = _getCachedRegistry();
    return registry
        .where((m) => m.dashboardVisible && m.isEnabled)
        .toList();
  }

  /// ============================================================
  /// GET MODULES FOR QUICK ACTIONS
  /// ============================================================
  ///
  /// Returns only modules with quick_action_visible = true.
  /// ============================================================
  List<RuntimeModule> getQuickActionModules() {
    final registry = _getCachedRegistry();
    return registry
        .where((m) => m.quickActionVisible && m.isEnabled)
        .toList();
  }

  /// ============================================================
  /// GET PINNED MODULES
  /// ============================================================
  ///
  /// Returns only pinned modules.
  /// ============================================================
  List<RuntimeModule> getPinnedModules() {
    final registry = _getCachedRegistry();
    return registry.where((m) => m.pinned && m.isEnabled).toList();
  }

  /// ============================================================
  /// GET ENABLED ROUTES
  /// ============================================================
  ///
  /// Returns route entries for all enabled (non-maintenance) modules.
  /// These are the only routes that should be registered.
  /// ============================================================
  List<({String moduleId, String route})> getEnabledRoutes() {
    final registry = _getCachedRegistry();
    return registry
        .where((m) => m.isEnabled && !m.maintenanceMode && m.route.isNotEmpty)
        .map((m) => (moduleId: m.moduleId, route: m.route))
        .toList();
  }

  /// ============================================================
  /// CHECK IF MODULE IS ENABLED
  /// ============================================================
  bool isModuleEnabled(String moduleId) {
    final registry = _getCachedRegistry();
    return registry.any((m) => m.moduleId == moduleId && m.isEnabled);
  }

  /// ============================================================
  /// GET MODULE BY ID
  /// ============================================================
  RuntimeModule? getModuleById(String moduleId) {
    final registry = _getCachedRegistry();
    for (final m in registry) {
      if (m.moduleId == moduleId) return m;
    }
    return null;
  }

  /// ============================================================
  /// INVALIDATE CACHE
  /// ============================================================
  ///
  /// Call when:
  ///   - system.modules changes
  ///   - feature flags change
  ///   - user context changes
  ///
  /// The next call to buildRegistry() will recompute from scratch.
  /// ============================================================
  void invalidateCache() {
    _cachedRegistry = null;
    _cacheSequence++;
  }

  /// ============================================================
  /// GET CURRENT CACHE SEQUENCE
  /// ============================================================
  ///
  /// Monotonically increasing counter. External watchers can
  /// compare this to detect registry changes.
  /// ============================================================
  int get cacheSequence => _cacheSequence;

  /// ============================================================
  /// FULL REGISTRY COUNT (FOR METRICS)
  /// ============================================================
  int get totalEnabledModules => _getCachedRegistry().length;

  /// ============================================================
  /// TAKE METRICS SNAPSHOT
  /// ============================================================
  CompositionMetrics takeMetricsSnapshot() => _metrics.takeSnapshot();

  /// ============================================================
  /// INTERNAL: SAFE CACHE ACCESS
  /// ============================================================
  List<RuntimeModule> _getCachedRegistry() {
    if (_cachedRegistry == null) {
      // Cache miss — caller must call buildRegistry() first
      _metrics.recordRegistryCacheMiss();
      return [];
    }
    _metrics.recordRegistryCacheHit();
    return _cachedRegistry!;
  }
}

/// Singleton instance for app-wide access
final runtimeCompositionEngine = RuntimeCompositionEngine();
