/// ============================================================
/// MODULE DESCRIPTOR REGISTRY (RUNTIME CATALOG)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/domain/models/ = composition domain models
///
/// ✅ Responsibilities:
///   - Pure catalog of all registered ModuleRuntimeDescriptors
///   - Lookup by module key
///   - List all registered descriptors
///
/// ❌ Does NOT:
///   - Import Flutter widgets
///   - Render UI
///   - Contain business logic
///   - Evaluate access control
/// ============================================================
library;

import 'module_descriptor.dart';

/// ============================================================
/// MODULE DESCRIPTOR REGISTRY
/// ============================================================
///
/// Static registry where every module registers its runtime descriptor.
/// This is the bridge between feature modules and the composition engine.
///
/// Usage:
///   ModuleDescriptorRegistry.register(marketplaceDescriptor);
///   ModuleDescriptorRegistry.register(farmManagementDescriptor);
/// ============================================================
class ModuleDescriptorRegistry {
  static final Map<String, ModuleRuntimeDescriptor> _descriptors = {};

  /// Register a module's runtime descriptor
  static void register(ModuleRuntimeDescriptor descriptor) {
    if (_descriptors.containsKey(descriptor.moduleKey)) {
      // Allow overwrite for hot reload scenarios
      _descriptors[descriptor.moduleKey] = descriptor;
      return;
    }
    _descriptors[descriptor.moduleKey] = descriptor;
  }

  /// Get a module's runtime descriptor by module key
  static ModuleRuntimeDescriptor? get(String moduleKey) {
    return _descriptors[moduleKey];
  }

  /// Check if a module has a registered descriptor
  static bool hasDescriptor(String moduleKey) {
    return _descriptors.containsKey(moduleKey);
  }

  /// Get all registered module keys
  static List<String> get registeredModuleKeys =>
      _descriptors.keys.toList();

  /// Get all registered descriptors
  static List<ModuleRuntimeDescriptor> get allDescriptors =>
      _descriptors.values.toList();

  /// Get dashboard widgets for a specific module
  static List<DashboardWidgetDescriptor> getDashboardWidgets(
      String moduleKey) {
    final descriptor = _descriptors[moduleKey];
    return descriptor?.dashboardWidgets ?? [];
  }

  /// Get home widgets for a specific module
  static List<HomeWidgetDescriptor> getHomeWidgets(String moduleKey) {
    final descriptor = _descriptors[moduleKey];
    return descriptor?.homeWidgets ?? [];
  }

  /// Get quick actions for a specific module
  static List<QuickActionDescriptor> getQuickActions(String moduleKey) {
    final descriptor = _descriptors[moduleKey];
    return descriptor?.quickActions ?? [];
  }

  /// Get notification providers for a specific module
  static List<NotificationProviderDescriptor> getNotificationProviders(
      String moduleKey) {
    final descriptor = _descriptors[moduleKey];
    return descriptor?.notificationProviders ?? [];
  }

  /// Get search providers for a specific module
  static List<SearchProviderDescriptor> getSearchProviders(
      String moduleKey) {
    final descriptor = _descriptors[moduleKey];
    return descriptor?.searchProviders ?? [];
  }

  /// Get analytics providers for a specific module
  static List<AnalyticsProviderDescriptor> getAnalyticsProviders(
      String moduleKey) {
    final descriptor = _descriptors[moduleKey];
    return descriptor?.analyticsProviders ?? [];
  }

  /// Get routes for a specific module
  static List<RouteDescriptor> getRoutes(String moduleKey) {
    final descriptor = _descriptors[moduleKey];
    return descriptor?.routes ?? [];
  }

  /// Get all dashboard widget descriptors from all modules
  static List<DashboardWidgetDescriptor> getAllDashboardWidgets() {
    final widgets = <DashboardWidgetDescriptor>[];
    for (final descriptor in _descriptors.values) {
      widgets.addAll(descriptor.dashboardWidgets);
    }
    return widgets;
  }

  /// Get all home widget descriptors from all modules
  static List<HomeWidgetDescriptor> getAllHomeWidgets() {
    final widgets = <HomeWidgetDescriptor>[];
    for (final descriptor in _descriptors.values) {
      widgets.addAll(descriptor.homeWidgets);
    }
    return widgets;
  }

  /// Get all quick action descriptors from all modules
  static List<QuickActionDescriptor> getAllQuickActions() {
    final actions = <QuickActionDescriptor>[];
    for (final descriptor in _descriptors.values) {
      actions.addAll(descriptor.quickActions);
    }
    return actions;
  }

  /// Get all notification provider descriptors from all modules
  static List<NotificationProviderDescriptor> getAllNotificationProviders() {
    final providers = <NotificationProviderDescriptor>[];
    for (final descriptor in _descriptors.values) {
      providers.addAll(descriptor.notificationProviders);
    }
    return providers;
  }

  /// Get all search provider descriptors from all modules
  static List<SearchProviderDescriptor> getAllSearchProviders() {
    final providers = <SearchProviderDescriptor>[];
    for (final descriptor in _descriptors.values) {
      providers.addAll(descriptor.searchProviders);
    }
    return providers;
  }

  /// Get all analytics provider descriptors from all modules
  static List<AnalyticsProviderDescriptor> getAllAnalyticsProviders() {
    final providers = <AnalyticsProviderDescriptor>[];
    for (final descriptor in _descriptors.values) {
      providers.addAll(descriptor.analyticsProviders);
    }
    return providers;
  }

  /// Clear all descriptors (testing/hot reload)
  static void clear() {
    _descriptors.clear();
  }
}
