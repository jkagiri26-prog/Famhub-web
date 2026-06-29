/// ============================================================
/// EXPORT DESCRIPTOR PROVIDERS
/// ============================================================
///
/// Re-export the descriptor providers so they're available
/// from a single import of this file.
/// ============================================================
library;
export 'package:famhub_app/core/composition/providers/descriptor_providers.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/domain/models/composition_metrics.dart';
import 'package:famhub_app/core/composition/engine/runtime_composition_engine.dart';
import 'package:famhub_app/core/composition/navigation/composition_nav_builder.dart';
import 'package:famhub_app/core/composition/dashboard/dashboard_composer.dart';
import 'package:famhub_app/core/navigation/runtime_refresh_provider.dart';

/// ============================================================
/// COMPOSITION PROVIDERS (RIVERPOD 3)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/providers/ = composition state management
///
/// ✅ Responsibilities:
///   - Provide runtime module registry via Riverpod
///   - Provide filtered views (sidebar, dashboard, etc.)
///   - Auto-invalidate on context/module changes
///   - Single source of truth for all composition data
///
/// ✅ PERFORMANCE:
///   - Single backend fetch for module metadata
///   - Registry caching in RuntimeCompositionEngine
///   - Provider-based invalidation only
///   - No rebuilding unchanged modules
/// ============================================================

/// ============================================================
/// PROVIDER: RUNTIME MODULE REGISTRY
/// ============================================================
///
/// The single source of truth for all runtime composition data.
/// Combines backend modules + EntityContext → resolved RuntimeModules.
///
/// Recomputes when either modules or context changes.
/// ============================================================
final runtimeModuleRegistryProvider =
    Provider<List<RuntimeModule>>((ref) {
  final modulesAsync = ref.watch(moduleProvider);
  final context = ref.watch(contextProvider);

  return modulesAsync.when(
    data: (modules) {
      return runtimeCompositionEngine.buildRegistry(
        modules: modules,
        context: context,
      );
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// ============================================================
/// PROVIDER: CACHE SEQUENCE
/// ============================================================
///
/// Monotonically increasing counter that changes every time
/// the registry is rebuilt. Useful for change detection.
/// ============================================================
final compositionCacheSequenceProvider = Provider<int>((ref) {
  ref.watch(runtimeModuleRegistryProvider);
  return runtimeCompositionEngine.cacheSequence;
});

/// ============================================================
/// PROVIDER: COMPOSITION METRICS
/// ============================================================
///
/// Provides the latest composition metrics snapshot.
/// Updated after each registry rebuild.
/// ============================================================
final compositionMetricsProvider = Provider<CompositionMetrics>((ref) {
  ref.watch(runtimeModuleRegistryProvider);
  return runtimeCompositionEngine.takeMetricsSnapshot();
});

/// ============================================================
/// PROVIDER: SIDEBAR NAVIGATION ITEMS
/// ============================================================
///
/// Computed from the runtime module registry.
/// Only modules with sidebar_visible = true appear here.
/// ============================================================
final compositionSidebarItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final registry = ref.watch(runtimeModuleRegistryProvider);
  return CompositionNavBuilder.getSidebarItems(registry);
});

/// ============================================================
/// PROVIDER: BOTTOM NAVIGATION ITEMS
/// ============================================================
///
/// Computed from the runtime module registry.
/// Only modules with bottom_nav_visible = true appear here.
/// ============================================================
final compositionBottomNavItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final registry = ref.watch(runtimeModuleRegistryProvider);
  return CompositionNavBuilder.getBottomNavItems(registry);
});

/// ============================================================
/// PROVIDER: DASHBOARD NAVIGATION ITEMS
/// ============================================================
///
/// Computed from the runtime module registry.
/// Only modules with dashboard_visible = true appear here.
/// ============================================================
final compositionDashboardNavItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final registry = ref.watch(runtimeModuleRegistryProvider);
  return CompositionNavBuilder.getDashboardItems(registry);
});

/// ============================================================
/// PROVIDER: QUICK ACTION ITEMS
/// ============================================================
///
/// Computed from the runtime module registry.
/// Only modules with quick_action_visible = true appear here.
/// ============================================================
final compositionQuickActionItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final registry = ref.watch(runtimeModuleRegistryProvider);
  return CompositionNavBuilder.getQuickActionItems(registry);
});

/// ============================================================
/// PROVIDER: PINNED MODULE ITEMS
/// ============================================================
///
/// Computed from the runtime module registry.
/// Only pinned modules appear here.
/// ============================================================
final compositionPinnedItemsProvider =
    Provider<List<CompositionNavItem>>((ref) {
  final registry = ref.watch(runtimeModuleRegistryProvider);
  return CompositionNavBuilder.getPinnedItems(registry);
});

/// ============================================================
/// PROVIDER: DASHBOARD COMPOSITION
/// ============================================================
///
/// Groups dashboard-visible modules into sections.
/// Used by the dashboard renderer for section-based layout.
/// ============================================================
final dashboardCompositionProvider =
    Provider<DashboardCompositionResult>((ref) {
  final registry = ref.watch(runtimeModuleRegistryProvider);
  final dashboardModules = registry
      .where((m) => m.isEnabled && !m.maintenanceMode && m.dashboardVisible)
      .toList();

  final composer = DashboardComposer();
  return composer.compose(modules: dashboardModules);
});

/// ============================================================
/// PROVIDER: ENABLED MODULE ROUTES
/// ============================================================
///
/// Returns route entries for all enabled modules.
/// Used by the DynamicRouteRegistrar.
/// ============================================================
final enabledModuleRoutesProvider =
    Provider<List<({String moduleId, String route})>>((ref) {
  final registry = ref.watch(runtimeModuleRegistryProvider);
  return registry
      .where((m) => m.isEnabled && !m.maintenanceMode && m.route.isNotEmpty)
      .map((m) => (moduleId: m.moduleId, route: m.route))
      .toList();
});

/// ============================================================
/// PROVIDER: MODULE ACCESS CHECK
/// ============================================================
///
/// Check if a specific module ID is enabled in the current context.
/// ============================================================
final moduleAccessProvider = Provider.family<bool, String>((ref, moduleId) {
  final registry = ref.watch(runtimeModuleRegistryProvider);
  return registry.any((m) => m.moduleId == moduleId && m.isEnabled);
});

/// ============================================================
/// RUNTIME REFRESH OBSERVER (COMPOSITION VERSION)
/// ============================================================
///
/// Watches for changes in modules and context,
/// then invalidates all composition providers.
///
/// Replacement for runtimeAutoInvalidatorProvider.
/// ============================================================
final compositionRuntimeRefreshProvider = Provider<void>((ref) {
  // Watch both sources reactively
  final modules = ref.watch(moduleProvider);
  // Watch context to auto-rebuild when user context changes
  ref.watch(contextProvider);

  // When data resolves, invalidate composition providers
  modules.when(
    data: (_) {
      _invalidateAllCompositionProviders(ref);
    },
    loading: () {},
    error: (_, __) {},
  );

  // Also invalidate on context changes
  ref.listen(contextProvider, (previous, next) {
    if (previous != next) {
      _invalidateAllCompositionProviders(ref);
    }
  });

  return;
});

/// ============================================================
/// INVALIDATE ALL COMPOSITION PROVIDERS
/// ============================================================
void _invalidateAllCompositionProviders(Ref ref) {
  ref.invalidate(runtimeModuleRegistryProvider);
  ref.invalidate(compositionSidebarItemsProvider);
  ref.invalidate(compositionBottomNavItemsProvider);
  ref.invalidate(compositionDashboardNavItemsProvider);
  ref.invalidate(compositionQuickActionItemsProvider);
  ref.invalidate(compositionPinnedItemsProvider);
  ref.invalidate(dashboardCompositionProvider);
  ref.invalidate(enabledModuleRoutesProvider);
  ref.invalidate(compositionMetricsProvider);
}
