/// ============================================================
/// RUNTIME DESCRIPTOR ENGINE (ENHANCED COMPOSITION)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/engine/ = composition engine layer
///
/// ✅ Responsibilities:
///   - Bridges ModuleRuntimeDescriptors with RuntimeModules
///   - Provides queries for all descriptor contributions
///   - Filters contributions by module enabled/active state
///   - NO hardcoded module identifiers
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Backend (system.modules) is the ONLY source of truth
///   - Only queries descriptors for modules that are enabled + active
///   - No switch statements, no hardcoded references
///   - Dashboard sections, quick actions, search, notifications all
///     come from descriptors, not hardcoded lists
/// ============================================================
library;

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor_registry.dart';

/// ============================================================
/// RUNTIME DESCRIPTOR ENGINE
/// ============================================================
///
/// Provides methods to query all runtime contributions
/// (dashboard widgets, quick actions, search providers, etc.)
/// based on the currently enabled RuntimeModules.
/// ============================================================
class RuntimeDescriptorEngine {
  /// ============================================================
  /// GET DASHBOARD WIDGETS FOR ENABLED MODULES
  /// ============================================================
  ///
  /// Returns all DashboardWidgetDescriptors from currently
  /// enabled modules. No hardcoded widget lists.
  /// ============================================================
  List<DashboardWidgetDescriptor> getDashboardWidgets(
    List<RuntimeModule> enabledModules,
  ) {
    final widgets = <DashboardWidgetDescriptor>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor != null) {
        widgets.addAll(descriptor.dashboardWidgets);
      }
    }

    // Sort by section then display order
    widgets.sort((a, b) {
      final sectionCompare = a.sectionKey.compareTo(b.sectionKey);
      if (sectionCompare != 0) return sectionCompare;
      return a.displayOrder.compareTo(b.displayOrder);
    });

    return widgets;
  }

  /// ============================================================
  /// GET HOME WIDGETS FOR ENABLED MODULES
  /// ============================================================
  ///
  /// Returns all HomeWidgetDescriptors from currently
  /// enabled modules. No hardcoded home widget lists.
  /// ============================================================
  List<HomeWidgetDescriptor> getHomeWidgets(
    List<RuntimeModule> enabledModules,
  ) {
    final widgets = <HomeWidgetDescriptor>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor != null) {
        widgets.addAll(descriptor.homeWidgets);
      }
    }

    // Sort by priority (highest first)
    widgets.sort((a, b) => b.priority.compareTo(a.priority));
    return widgets;
  }

  /// ============================================================
  /// GET QUICK ACTIONS FOR ENABLED MODULES
  /// ============================================================
  ///
  /// Returns all QuickActionDescriptors from currently
  /// enabled modules. No hardcoded quick action lists.
  /// ============================================================
  List<QuickActionDescriptor> getQuickActions(
    List<RuntimeModule> enabledModules,
  ) {
    final actions = <QuickActionDescriptor>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;
      if (!module.quickActionVisible) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor != null) {
        actions.addAll(descriptor.quickActions);
      }
    }

    // Sort by display order (primary first)
    actions.sort((a, b) {
      if (a.isPrimary && !b.isPrimary) return -1;
      if (!a.isPrimary && b.isPrimary) return 1;
      return a.displayOrder.compareTo(b.displayOrder);
    });

    return actions;
  }

  /// ============================================================
  /// GET NOTIFICATION PROVIDERS FOR ENABLED MODULES
  /// ============================================================
  ///
  /// Returns all NotificationProviderDescriptors from currently
  /// enabled modules. No hardcoded notification provider lists.
  /// ============================================================
  List<NotificationProviderDescriptor> getNotificationProviders(
    List<RuntimeModule> enabledModules,
  ) {
    final providers = <NotificationProviderDescriptor>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor != null) {
        providers.addAll(descriptor.notificationProviders);
      }
    }

    return providers;
  }

  /// ============================================================
  /// GET SEARCH PROVIDERS FOR ENABLED MODULES
  /// ============================================================
  ///
  /// Returns all SearchProviderDescriptors from currently
  /// enabled modules. No hardcoded search source lists.
  /// ============================================================
  List<SearchProviderDescriptor> getSearchProviders(
    List<RuntimeModule> enabledModules,
  ) {
    final providers = <SearchProviderDescriptor>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor != null) {
        providers.addAll(descriptor.searchProviders);
      }
    }

    return providers;
  }

  /// ============================================================
  /// GET ANALYTICS PROVIDERS FOR ENABLED MODULES
  /// ============================================================
  ///
  /// Returns all AnalyticsProviderDescriptors from currently
  /// enabled modules. No hardcoded analytics lists.
  /// ============================================================
  List<AnalyticsProviderDescriptor> getAnalyticsProviders(
    List<RuntimeModule> enabledModules,
  ) {
    final providers = <AnalyticsProviderDescriptor>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor != null) {
        providers.addAll(descriptor.analyticsProviders);
      }
    }

    return providers;
  }

  /// ============================================================
  /// GET ALL SEARCHABLE ENTITY TYPES
  /// ============================================================
  ///
  /// Aggregates all searchable entity types from enabled modules.
  /// Used by the global search engine.
  /// ============================================================
  List<String> getSearchableEntityTypes(
    List<RuntimeModule> enabledModules,
  ) {
    final entityTypes = <String>{};

    for (final provider in getSearchProviders(enabledModules)) {
      entityTypes.addAll(provider.entityTypes);
    }

    return entityTypes.toList();
  }

  /// ============================================================
  /// GET ALL NOTIFICATION TYPES
  /// ============================================================
  ///
  /// Aggregates all notification types from enabled modules.
  /// Used by the Notification Center.
  /// ============================================================
  List<String> getNotificationTypes(
    List<RuntimeModule> enabledModules,
  ) {
    final types = <String>{};

    for (final provider in getNotificationProviders(enabledModules)) {
      types.addAll(provider.notificationTypes);
    }

    return types.toList();
  }

  /// ============================================================
  /// GET MODULE ROUTES
  /// ============================================================
  ///
  /// Returns all RouteDescriptors from currently enabled modules.
  /// ============================================================
  List<RouteDescriptor> getModuleRoutes(
    List<RuntimeModule> enabledModules,
  ) {
    final routes = <RouteDescriptor>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor != null) {
        routes.addAll(descriptor.routes);
      }
    }

    return routes;
  }

  /// ============================================================
  /// GET MODULE PERMISSIONS
  /// ============================================================
  ///
  /// Returns all PermissionDescriptors from currently enabled modules.
  /// ============================================================
  List<PermissionDescriptor> getModulePermissions(
    List<RuntimeModule> enabledModules,
  ) {
    final permissions = <PermissionDescriptor>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor != null) {
        permissions.addAll(descriptor.permissions);
      }
    }

    return permissions;
  }

  /// ============================================================
  /// ORGANIZE DASHBOARD WIDGETS BY SECTION
  /// ============================================================
  ///
  /// Groups dashboard widgets by their sectionKey.
  /// Returns a Map<sectionKey, List<DashboardWidgetDescriptor>>.
  /// ============================================================
  Map<String, List<DashboardWidgetDescriptor>> organizeWidgetsBySection(
    List<RuntimeModule> enabledModules,
  ) {
    final sectionMap = <String, List<DashboardWidgetDescriptor>>{};

    for (final widget in getDashboardWidgets(enabledModules)) {
      sectionMap.putIfAbsent(widget.sectionKey, () => []);
      sectionMap[widget.sectionKey]!.add(widget);
    }

    return sectionMap;
  }

  /// ============================================================
  /// ORGANIZE HOME WIDGETS BY TYPE
  /// ============================================================
  ///
  /// Groups home widgets by their widgetType.
  /// Returns a Map<widgetType, List<HomeWidgetDescriptor>>.
  /// ============================================================
  Map<String, List<HomeWidgetDescriptor>> organizeHomeWidgetsByType(
    List<RuntimeModule> enabledModules,
  ) {
    final typeMap = <String, List<HomeWidgetDescriptor>>{};

    for (final widget in getHomeWidgets(enabledModules)) {
      typeMap.putIfAbsent(widget.widgetType, () => []);
      typeMap[widget.widgetType]!.add(widget);
    }

    return typeMap;
  }
}

/// Singleton instance for app-wide access
final runtimeDescriptorEngine = RuntimeDescriptorEngine();
