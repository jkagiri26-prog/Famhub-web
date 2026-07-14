/// ============================================================
/// CAPABILITY COMPOSITION BRIDGE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/capabilities/composition/ = composition integration
///
/// This bridge integrates the Capability Engine into the
/// runtime composition pipeline.
///
/// Current pipeline:
///   Modules → RuntimeDescriptorEngine → Navigation → Dashboard
///
/// Target pipeline:
///   Organization → Capability Profile → Capability Engine →
///   RuntimeDescriptorEngine → Navigation → Dashboard
///
/// ✅ Responsibilities:
///   - Filter module descriptors based on capabilities
///   - Filter dashboard widgets based on capabilities
///   - Filter navigation items based on capabilities
///   - Enable/disable workflow steps based on capabilities
///
/// ❌ Does NOT:
///   - Replace RuntimeFeatureFlags
///   - Render UI
///   - Import Flutter widgets
/// ============================================================
library;

import 'package:famhub_app/core/capabilities/application/capability_engine.dart';
import 'package:famhub_app/core/capabilities/domain/capability.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';

/// ============================================================
/// CAPABILITY-AWARE MODULE DESCRIPTOR
/// ============================================================
///
/// Extends the standard ModuleRuntimeDescriptor with
/// capability requirements.
///
/// Usage:
///   Modules declare what capabilities their features require.
///   The CapabilityCompositionBridge filters based on the engine.
/// ============================================================

/// Extension on ModuleRuntimeDescriptor to add capability metadata.
/// This allows modules to declare required capabilities without
/// modifying the base descriptor model.
extension CapabilityModuleDescriptor on ModuleRuntimeDescriptor {
  /// Required capabilities for the module to function.
  /// If empty, no capability check is performed.
  List<String> get requiredCapabilities =>
      _capabilityExtensions[moduleKey]?.requiredCapabilities ?? [];

  /// Dashboard widgets with their capability requirements.
  Map<String, List<String>> get widgetCapabilities =>
      _capabilityExtensions[moduleKey]?.widgetCapabilities ?? {};
}

/// ============================================================
/// CAPABILITY EXTENSION STORAGE
/// ============================================================
///
/// Stores capability requirements mapped to module/widget keys.
/// Separate from ModuleRuntimeDescriptor to avoid modifying it.
/// ============================================================
class CapabilityModuleExtension {
  final String moduleKey;
  final List<String> requiredCapabilities;
  final Map<String, List<String>> widgetCapabilities;

  const CapabilityModuleExtension({
    required this.moduleKey,
    this.requiredCapabilities = const [],
    this.widgetCapabilities = const {},
  });
}

/// Internal storage for capability extensions.
final Map<String, CapabilityModuleExtension> _capabilityExtensions = {};

/// ============================================================
/// REGISTER MODULE CAPABILITY EXTENSION
/// ============================================================
///
/// Called by modules during initialization to declare their
/// capability requirements.
///
/// Usage:
///   registerModuleCapabilities(
///     'marketplace',
///     requiredCapabilities: ['marketplace.listings'],
///     widgetCapabilities: {
///       'inventory_section': ['inventory.stock'],
///       'orders_section': ['marketplace.orders'],
///       'finance_summary': ['finance.recording'],
///     },
///   );
/// ============================================================
void registerModuleCapabilities(
  String moduleKey, {
  List<String> requiredCapabilities = const [],
  Map<String, List<String>> widgetCapabilities = const {},
}) {
  _capabilityExtensions[moduleKey] = CapabilityModuleExtension(
    moduleKey: moduleKey,
    requiredCapabilities: requiredCapabilities,
    widgetCapabilities: widgetCapabilities,
  );
}

/// ============================================================
/// CAPABILITY COMPOSITION BRIDGE
/// ============================================================
///
/// Pure filtering bridge. Takes a CapabilityEngine and composition
/// inputs, returns capability-filtered outputs.
/// ============================================================
class CapabilityCompositionBridge {
  final CapabilityEngine engine;

  const CapabilityCompositionBridge({required this.engine});

  /// ============================================================
  /// FILTER DASHBOARD WIDGETS
  /// ============================================================
  ///
  /// Removes dashboard widgets whose required capabilities
  /// are not available.
  ///
  /// Example:
  ///   Inventory Card requires inventory.stock
  ///   Financial Summary requires finance.recording
  ///   If missing → widget is removed from the list
  /// ============================================================
  List<DashboardWidgetDescriptor> filterDashboardWidgets(
    List<DashboardWidgetDescriptor> widgets,
  ) {
    return widgets.where((widget) {
      // Check if the widget's module has capability requirements
      final moduleExt = _capabilityExtensions[widget.moduleKey];
      if (moduleExt == null) return true; // No capability constraints

      // Check widget-specific capabilities
      final widgetCaps = moduleExt.widgetCapabilities[widget.widgetKey];
      if (widgetCaps != null && widgetCaps.isNotEmpty) {
        return widgetCaps.every((cap) => engine.hasCapability(cap));
      }

      return true; // No widget-specific constraints
    }).toList();
  }

  /// ============================================================
  /// CHECK MODULE VIABILITY
  /// ============================================================
  ///
  /// Checks if a module should be considered viable based on
  /// its required capabilities.
  ///
  /// Even if a module is enabled, if none of its capabilities
  /// are available, it should not be rendered.
  /// ============================================================
  bool isModuleViable(String moduleKey) {
    final moduleExt = _capabilityExtensions[moduleKey];
    if (moduleExt == null) return true; // No capability constraints

    final requiredCaps = moduleExt.requiredCapabilities;
    if (requiredCaps.isEmpty) return true; // No specific requirements

    return requiredCaps.every((cap) => engine.hasCapability(cap));
  }

  /// ============================================================
  /// FILTER NAV ITEMS
  /// ============================================================
  ///
  /// Filters navigation items based on module viability.
  /// Non-viable modules are removed from navigation.
  ///
  /// Note: This only HIDES the nav item. The module itself
  /// remains registered but inaccessible through navigation.
  /// ============================================================
  List<T> filterNavItems<T>(List<T> items, String Function(T) moduleKeyOf) {
    return items.where((item) {
      final moduleKey = moduleKeyOf(item);
      return isModuleViable(moduleKey);
    }).toList();
  }

  /// ============================================================
  /// GET ENABLED WORKFLOW STAGES
  /// ============================================================
  ///
  /// Returns the list of workflow stages that should be enabled
  /// based on available capabilities.
  ///
  /// Example:
  ///   Stage 1: Activity → always available if workflow.execution enabled
  ///   Stage 2: Inventory → requires inventory.stock
  ///   Stage 3: Financial → requires finance.recording
  ///   Stage 4: KPIs → requires analytics.basic
  ///   Stage 5: Automation → requires level >= 5
  /// ============================================================
  List<CapabilityWorkflowStage> getEnabledWorkflowStages({
    required List<CapabilityWorkflowStage> allStages,
  }) {
    return allStages.where((stage) {
      if (stage.requiredCapabilityId == null) return true;
      return engine.hasCapability(stage.requiredCapabilityId!);
    }).toList();
  }

  /// ============================================================
  /// CHECK FEATURE LEVEL
  /// ============================================================
  ///
  /// Returns true if the capability is at or above the minimum level.
  /// Useful for graduated feature access within a single capability.
  /// ============================================================
  bool hasMinimumLevel(Object capability, int minimumLevel) {
    return engine.getCapabilityLevel(capability) >= minimumLevel;
  }
}

/// ============================================================
/// CAPABILITY WORKFLOW STAGE
/// ============================================================
///
/// Defines a workflow stage with its capability requirement.
/// Used by DynamicActivityWorkflowService to determine which
/// stages are available.
/// ============================================================
class CapabilityWorkflowStage {
  /// Stage identifier
  final String stageKey;

  /// Display name
  final String displayName;

  /// Optional capability required for this stage
  final String? requiredCapabilityId;

  /// Minimum capability level required (default: 1)
  final int minimumLevel;

  /// Whether this stage is optional (skip if capability missing)
  final bool isOptional;

  const CapabilityWorkflowStage({
    required this.stageKey,
    required this.displayName,
    this.requiredCapabilityId,
    this.minimumLevel = 1,
    this.isOptional = true,
  });
}
