/// ============================================================
/// DESCRIPTOR PROVIDERS (RUNTIME COMPOSITION)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/providers/ = composition state management
///
/// ✅ Responsibilities:
///   - Provide runtime descriptor data to UI components
///   - Wire RuntimeCompositionEngine + RuntimeDescriptorEngine together
///   - Auto-invalidate when modules or context change
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Backend (system.modules) is the ONLY source of truth
///   - All data flows through RuntimeModule list
///   - No hardcoded module identifiers
///   - Descriptors only contribute metadata, not widget trees
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/composition/engine/runtime_composition_engine.dart';
import 'package:famhub_app/core/composition/engine/runtime_descriptor_engine.dart';
import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';

/// ============================================================
/// PROVIDER: ENABLED RUNTIME MODULES
/// ============================================================
///
/// Returns the list of RuntimeModules after full composition pipeline:
///   1. Fetch SystemModules from backend
///   2. Map to RuntimeModules
///   3. Apply Context Engine filtering
///   4. Resolve dependencies
///   5. Cache the result
///
/// This is the SINGLE source of what modules are available for the user.
/// ============================================================
final enabledRuntimeModulesProvider = FutureProvider<List<RuntimeModule>>((ref) async {
  final modulesAsync = await ref.watch(moduleProvider.future);
  final context = ref.watch(contextProvider);

  // Build the runtime registry through the composition pipeline
  final registry = runtimeCompositionEngine.buildRegistry(
    modules: modulesAsync,
    context: context,
  );

  return registry;
});

/// ============================================================
/// PROVIDER: DASHBOARD WIDGET DESCRIPTORS
/// ============================================================
///
/// Returns all DashboardWidgetDescriptors from enabled modules.
/// Dashboard engine renders these, not hardcoded widget lists.
/// ============================================================
final dashboardWidgetDescriptorsProvider = FutureProvider<List<DashboardWidgetDescriptor>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.getDashboardWidgets(modules);
});

/// ============================================================
/// PROVIDER: HOME WIDGET DESCRIPTORS
/// ============================================================
///
/// Returns all HomeWidgetDescriptors from enabled modules.
/// Home screen composes these dynamically.
/// ============================================================
final homeWidgetDescriptorsProvider = FutureProvider<List<HomeWidgetDescriptor>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.getHomeWidgets(modules);
});

/// ============================================================
/// PROVIDER: QUICK ACTION DESCRIPTORS
/// ============================================================
///
/// Returns all QuickActionDescriptors from enabled modules.
/// Quick actions are runtime-generated, not hardcoded.
/// ============================================================
final quickActionDescriptorsProvider = FutureProvider<List<QuickActionDescriptor>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.getQuickActions(modules);
});

/// ============================================================
/// PROVIDER: NOTIFICATION PROVIDER DESCRIPTORS
/// ============================================================
///
/// Returns all NotificationProviderDescriptors from enabled modules.
/// Notification Center aggregates these automatically.
/// ============================================================
final notificationProviderDescriptorsProvider = FutureProvider<List<NotificationProviderDescriptor>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.getNotificationProviders(modules);
});

/// ============================================================
/// PROVIDER: SEARCH PROVIDER DESCRIPTORS
/// ============================================================
///
/// Returns all SearchProviderDescriptors from enabled modules.
/// Global search engine aggregates these automatically.
/// ============================================================
final searchProviderDescriptorsProvider = FutureProvider<List<SearchProviderDescriptor>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.getSearchProviders(modules);
});

/// ============================================================
/// PROVIDER: ANALYTICS PROVIDER DESCRIPTORS
/// ============================================================
///
/// Returns all AnalyticsProviderDescriptors from enabled modules.
/// ============================================================
final analyticsProviderDescriptorsProvider = FutureProvider<List<AnalyticsProviderDescriptor>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.getAnalyticsProviders(modules);
});

/// ============================================================
/// PROVIDER: SEARCHABLE ENTITY TYPES
/// ============================================================
///
/// Returns all unique searchable entity types from enabled modules.
/// Used by global search engine.
/// ============================================================
final searchableEntityTypesProvider = FutureProvider<List<String>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.getSearchableEntityTypes(modules);
});

/// ============================================================
/// PROVIDER: DASHBOARD WIDGETS BY SECTION
/// ============================================================
///
/// Returns dashboard widgets organized by section.
/// The dashboard renderer uses this to build sections dynamically.
/// ============================================================
final dashboardWidgetsBySectionProvider = FutureProvider<Map<String, List<DashboardWidgetDescriptor>>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.organizeWidgetsBySection(modules);
});

/// ============================================================
/// PROVIDER: HOME WIDGETS BY TYPE
/// ============================================================
///
/// Returns home widgets organized by type.
/// Home screen renderer uses this to build sections dynamically.
/// ============================================================
final homeWidgetsByTypeProvider = FutureProvider<Map<String, List<HomeWidgetDescriptor>>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.organizeHomeWidgetsByType(modules);
});

/// ============================================================
/// PROVIDER: MODULE ROUTE DESCRIPTORS
/// ============================================================
///
/// Returns all route descriptors from enabled modules.
/// Used by the dynamic route registrar to build routes.
/// ============================================================
final moduleRouteDescriptorsProvider = FutureProvider<List<RouteDescriptor>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.getModuleRoutes(modules);
});

/// ============================================================
/// PROVIDER: MODULE-SPECIFIC WIDGET DESCRIPTORS (FAMILY)
/// ============================================================
///
/// Returns only DashboardWidgetDescriptors for a specific moduleKey.
/// Module pages use this to render their own dashboard widgets.
/// ============================================================
final moduleWidgetDescriptorsProvider =
    FutureProvider.family<List<DashboardWidgetDescriptor>, String>(
  (ref, moduleKey) async {
    final allWidgets =
        await ref.watch(dashboardWidgetDescriptorsProvider.future);
    return allWidgets
        .where((w) => w.moduleKey == moduleKey)
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  },
);

/// ============================================================
/// PROVIDER: SHELL EXTENSION DESCRIPTORS
/// ============================================================
///
/// Returns all ShellExtensionDescriptors from enabled, non-maintenance
/// modules. The shell ExtensionSlot widget watches this provider
/// to render runtime-driven extensions.
///
/// 🎯 Single source of truth for shell extensions:
///   - Disabled modules → extensions automatically disappear
///   - Maintenance mode → extensions automatically hidden
///   - Feature flags → evaluated at build time
///   - Hot reload / module install → extensions update reactively
///
/// ⚡ The shell remains a consumer only:
///   - Module → Module Runtime → Descriptor Engine → Provider → Shell
///   - Shell never imports feature modules
///   - Shell never hardcodes extension IDs
/// ============================================================
final shellExtensionDescriptorsProvider =
    FutureProvider<List<ShellExtensionDescriptor>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return runtimeDescriptorEngine.getShellExtensions(modules);
});
