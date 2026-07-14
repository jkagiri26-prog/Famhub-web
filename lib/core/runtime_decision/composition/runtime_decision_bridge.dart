/// ============================================================
/// RUNTIME DECISION BRIDGE — COMPOSITION FILTERING
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/runtime_decision/composition/ = composition integration
///
/// The RuntimeDecisionBridge replaces multiple independent
/// filters (CapabilityCompositionBridge, policy checks,
/// feature flag checks) with a single unified bridge.
///
/// ✅ RESPONSIBILITIES:
///   - filterNavigation()    — Filter nav items by runtime decision
///   - filterRoutes()        — Filter available routes
///   - filterWidgets()       — Filter dashboard widgets
///   - filterDashboard()     — Filter dashboard sections
///   - filterQuickActions()  — Filter quick action items
///   - filterWorkflow()      — Filter workflow stages
///   - filterActions()       — Filter available actions
///
/// ✅ ARCHITECTURE PRINCIPLE:
///   Instead of:
///     if (capability...) if (policy...) if (featureFlag...)
///
///   Use:
///     bridge.canNavigate('marketplace')
///     bridge.canRender('marketplace', 'kpi_card')
///
/// ❌ Does NOT:
///   - Render UI
///   - Import Flutter widgets
///   - Access Supabase
/// ============================================================
library;

import 'package:famhub_app/core/runtime_decision/domain/runtime_request.dart';
import 'package:famhub_app/core/runtime_decision/domain/runtime_decision.dart';
import 'package:famhub_app/core/runtime_decision/application/runtime_decision_engine.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/composition/navigation/composition_nav_builder.dart';

/// ============================================================
/// RUNTIME DECISION BRIDGE
/// ============================================================
///
/// Single bridge for all composition filtering needs.
/// Replaces CapabilityCompositionBridge + individual filters.
/// ============================================================
class RuntimeDecisionBridge {
  final RuntimeDecisionEngine engine;

  const RuntimeDecisionBridge({required this.engine});

  // ============================================================
  // NAVIGATION FILTERING
  // ============================================================

  /// ============================================================
  /// FILTER NAVIGATION ITEMS
  /// ============================================================
  ///
  /// Removes navigation items whose modules fail the
  /// runtime decision check.
  ///
  /// Usage:
  ///   final allowedNav = bridge.filterNavigation(navItems);
  /// ============================================================
  List<T> filterNavigation<T>(
    List<T> items,
    String Function(T) moduleKeyOf,
  ) {
    return items.where((item) {
      final moduleKey = moduleKeyOf(item);
      return engine.canNavigate(moduleKey);
    }).toList();
  }

  /// ============================================================
  /// FILTER COMPOSITION NAV ITEMS
  /// ============================================================
  ///
  /// Convenience method for CompositionNavItem lists.
  /// ============================================================
  List<CompositionNavItem> filterCompositionNavItems(
    List<CompositionNavItem> items,
  ) {
    return items.where((item) {
      return engine.canNavigate(item.moduleKey);
    }).toList();
  }

  // ============================================================
  // ROUTE FILTERING
  // ============================================================

  /// ============================================================
  /// FILTER ROUTES
  /// ============================================================
  ///
  /// Filters a list of route entries by module access.
  ///
  /// Usage:
  ///   final allowedRoutes = bridge.filterRoutes(allRoutes);
  /// ============================================================
  List<({String moduleId, String route})> filterRoutes(
    List<({String moduleId, String route})> routes,
  ) {
    return routes.where((route) {
      return engine.canNavigate(route.moduleId);
    }).toList();
  }

  // ============================================================
  // DASHBOARD WIDGET FILTERING
  // ============================================================

  /// ============================================================
  /// FILTER DASHBOARD WIDGETS
  /// ============================================================
  ///
  /// Removes dashboard widgets whose modules fail the
  /// runtime decision check.
  ///
  /// Usage:
  ///   final allowedWidgets = bridge.filterWidgets(widgets);
  /// ============================================================
  List<DashboardWidgetDescriptor> filterWidgets(
    List<DashboardWidgetDescriptor> widgets,
  ) {
    return widgets.where((widget) {
      // Check if the module can render this widget
      return engine.canRender(widget.moduleKey, widget.widgetKey);
    }).toList();
  }

  // ============================================================
  // DASHBOARD FILTERING
  // ============================================================

  /// ============================================================
  /// FILTER DASHBOARD
  /// ============================================================
  ///
  /// Filters dashboard data by module access.
  ///
  /// Usage:
  ///   final allowedDashboard = bridge.filterDashboard(dashboard);
  /// ============================================================
  Map<String, List<DashboardWidgetDescriptor>> filterDashboard(
    Map<String, List<DashboardWidgetDescriptor>> sections,
  ) {
    final filtered = <String, List<DashboardWidgetDescriptor>>{};
    for (final entry in sections.entries) {
      final filteredWidgets = filterWidgets(entry.value);
      if (filteredWidgets.isNotEmpty) {
        filtered[entry.key] = filteredWidgets;
      }
    }
    return filtered;
  }

  // ============================================================
  // QUICK ACTION FILTERING
  // ============================================================

  /// ============================================================
  /// FILTER QUICK ACTIONS
  /// ============================================================
  ///
  /// Removes quick action items whose modules are not accessible.
  ///
  /// Usage:
  ///   final allowedActions = bridge.filterQuickActions(actions);
  /// ============================================================
  List<CompositionNavItem> filterQuickActions(
    List<CompositionNavItem> items,
  ) {
    return items.where((item) {
      return engine.canNavigate(item.moduleKey);
    }).toList();
  }

  // ============================================================
  // WORKFLOW FILTERING
  // ============================================================

  /// ============================================================
  /// FILTER WORKFLOW
  /// ============================================================
  ///
  /// Checks if a workflow stage should be accessible.
  ///
  /// Usage:
  ///   final allowedWorkflow = bridge.filterWorkflow(stages);
  /// ============================================================
  List<String> filterWorkflow(
    List<String> stageKeys,
    String module,
  ) {
    if (!engine.canExecute(module, 'workflow')) {
      return [];
    }
    return stageKeys.where((stage) {
      return engine.canExecute(module, stage);
    }).toList();
  }

  // ============================================================
  // ACTION FILTERING
  // ============================================================

  /// ============================================================
  /// FILTER ACTIONS
  /// ============================================================
  ///
  /// Filters a list of action identifiers by runtime decision.
  ///
  /// Usage:
  ///   final allowedActions = bridge.filterActions(actions, 'marketplace');
  /// ============================================================
  List<String> filterActions(
    List<String> actions,
    String module,
  ) {
    return actions.where((action) {
      return engine.canExecute(module, action);
    }).toList();
  }

  // ============================================================
  // CONVENIENCE WRAPPERS
  // ============================================================

  /// Check if a module can be navigated to
  bool canNavigate(String module) => engine.canNavigate(module);

  /// Check if a widget can render
  bool canRender(String module, String widget) =>
      engine.canRender(module, widget);

  /// Check if an action can execute
  bool canExecute(String module, String action) =>
      engine.canExecute(module, action);

  /// Check if approval is allowed
  bool canApprove(String module) => engine.canApprove(module);

  /// Check if delete is allowed
  bool canDelete(String module) => engine.canDelete(module);

  /// Check if create is allowed
  bool canCreate(String module) => engine.canCreate(module);

  /// Check if edit is allowed
  bool canEdit(String module) => engine.canEdit(module);

  /// Check if purchase is allowed
  bool canPurchase(String module) => engine.canPurchase(module);

  /// Check if sell is allowed
  bool canSell(String module) => engine.canSell(module);

  /// Check if export is allowed
  bool canExport(String module) => engine.canExport(module);

  /// Check if upload is allowed
  bool canUpload(String module) => engine.canUpload(module);

  /// Check if analytics can be viewed
  bool canViewAnalytics(String module) =>
      engine.canViewAnalytics(module);

  /// Check if AI can be used
  bool canUseAI(String module) => engine.canUseAI(module);

  /// Check if staff can be managed
  bool canManageStaff(String module) =>
      engine.canManageStaff(module);

  /// Check if workflow can be accessed
  bool canAccessWorkflow(String module) =>
      engine.canAccessWorkflow(module);

  /// Get detailed decision for a navigation check
  RuntimeDecision evaluateNavigation(String module) =>
      engine.evaluateNavigation(module);

  /// Get detailed decision for a render check
  RuntimeDecision evaluateRender(String module, String widget) =>
      engine.evaluateRender(module, widget);

  /// Get detailed decision for an execution check
  RuntimeDecision evaluateExecution(String module, String action) =>
      engine.evaluateExecution(module, action);
}

/// ============================================================
/// DASHBOARD WIDGET DESCRIPTOR (REFERENCE)
/// ============================================================
///
/// This file uses the external DashboardWidgetDescriptor from
/// core/dashboard_bridge/domain/models/dashboard_widget_descriptor.dart
///
/// If that file doesn't exist yet, uncomment and use the local
/// definition below as a fallback.
/// ============================================================
// /// Placeholder for DashboardWidgetDescriptor
// /// Actual model should be in core/dashboard_bridge/domain/models/
// class DashboardWidgetDescriptor {
//   final String widgetKey;
//   final String displayName;
//   final String moduleKey;
//   final IconData icon;
//   final int displayOrder;
//
//   const DashboardWidgetDescriptor({
//     required this.widgetKey,
//     required this.displayName,
//     required this.moduleKey,
//     required this.icon,
//     this.displayOrder = 0,
//   });
// }
