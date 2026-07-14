/// ============================================================
/// POLICY COMPOSITION BRIDGE — LOCATION-AWARE FILTERING
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/composition/ = composition integration
///
/// This bridge integrates the Policy Engine into the runtime
/// composition pipeline. It provides pure filtering methods
/// for navigation, dashboard, widgets, workflows, and menus.
///
/// No UI. Pure filtering.
///
/// ✅ Responsibilities:
///   - Filter navigation items by location policy
///   - Filter dashboard widgets by location policy
///   - Filter quick actions by location policy
///   - Filter workflow stages by location policy
///   - Filter routes by location policy
///   - Filter menu items by location policy
///
/// ❌ Does NOT:
///   - Render UI
///   - Replace CapabilityCompositionBridge
///   - Replace AccessDecisionEngine
///   - Import Flutter widgets
/// ============================================================
library;

import 'package:famhub_app/core/policies/application/policy_engine.dart';
import 'package:famhub_app/core/policies/domain/policy.dart';

/// ============================================================
/// POLICY-ENABLED COMPOSITION ITEM
/// ============================================================
///
/// Extends composition items with policy requirement metadata.
/// Items declare what policy rules their visibility depends on.
/// ============================================================

/// A navigation/dashboard item that has policy requirements.
abstract class PolicyFilterableItem {
  /// The module key this item belongs to.
  String get moduleKey;

  /// Optional policy rules required for this item to be visible.
  /// If empty/null, no policy check is performed.
  List<String> get requiredPolicyRules;
}

/// ============================================================
/// POLICY COMPOSITION BRIDGE
/// ============================================================
///
/// Pure filtering bridge. Takes a PolicyEngine and composition
/// inputs, returns policy-filtered outputs.
///
/// Default: If a module/item has no policy requirements, it
/// PASSES through (visible by default).
///
/// Never evaluate policy themselves inside widgets.
/// ============================================================
class PolicyCompositionBridge {
  final PolicyEngine engine;

  const PolicyCompositionBridge({required this.engine});

  /// ============================================================
  /// FILTER NAVIGATION
  /// ============================================================
  ///
  /// Filters navigation items based on policy rules.
  /// Items that require a policy rule that is not allowed
  /// are removed from the list.
  ///
  /// Used by Sidebar, Bottom Navigation, Quick Actions.
  /// ============================================================
  List<T> filterNavigation<T extends PolicyFilterableItem>(
    List<T> items,
  ) {
    return items.where((item) => _isItemAllowed(item)).toList();
  }

  /// ============================================================
  /// FILTER DASHBOARD
  /// ============================================================
  ///
  /// Filters dashboard sections/widgets based on policy rules.
  /// ============================================================
  List<T> filterDashboard<T extends PolicyFilterableItem>(
    List<T> items,
  ) {
    return items.where((item) => _isItemAllowed(item)).toList();
  }

  /// ============================================================
  /// FILTER QUICK ACTIONS
  /// ============================================================
  ///
  /// Filters quick action items based on policy rules.
  /// ============================================================
  List<T> filterQuickActions<T extends PolicyFilterableItem>(
    List<T> items,
  ) {
    return items.where((item) => _isItemAllowed(item)).toList();
  }

  /// ============================================================
  /// FILTER WIDGETS
  /// ============================================================
  ///
  /// Filters dashboard/home widgets based on policy rules.
  /// ============================================================
  List<T> filterWidgets<T extends PolicyFilterableItem>(
    List<T> items,
  ) {
    return items.where((item) => _isItemAllowed(item)).toList();
  }

  /// ============================================================
  /// FILTER WORKFLOW STAGES
  /// ============================================================
  ///
  /// Filters workflow stages based on policy rules.
  /// Workflow execution itself must pass through
  /// Policies.workflowExecution check first.
  /// ============================================================
  List<PolicyWorkflowStage> filterWorkflowStages(
    List<PolicyWorkflowStage> stages,
  ) {
    // First check if workflow execution is allowed at all
    if (!engine.isAllowed(Policies.workflowExecution)) {
      return [];
    }

    return stages.where((stage) {
      if (stage.requiredPolicyRule == null) return true;
      return engine.isAllowed(stage.requiredPolicyRule!);
    }).toList();
  }

  /// ============================================================
  /// FILTER ACTIONS
  /// ============================================================
  ///
  /// Filters action items (buttons, menu items, etc.) based on
  /// policy rules.
  /// ============================================================
  List<T> filterActions<T extends PolicyFilterableItem>(
    List<T> items,
  ) {
    return items.where((item) => _isItemAllowed(item)).toList();
  }

  /// ============================================================
  /// FILTER MENU
  /// ============================================================
  ///
  /// Filters menu items based on policy rules.
  /// ============================================================
  List<T> filterMenu<T extends PolicyFilterableItem>(
    List<T> items,
  ) {
    return items.where((item) => _isItemAllowed(item)).toList();
  }

  /// ============================================================
  /// FILTER ROUTES
  /// ============================================================
  ///
  /// Filters route entries based on policy rules.
  /// Routes whose required policy rule is not allowed
  /// are removed.
  /// ============================================================
  List<T> filterRoutes<T extends PolicyFilterableItem>(
    List<T> items,
  ) {
    return items.where((item) => _isItemAllowed(item)).toList();
  }

  /// ============================================================
  /// CHECK MODULE POLICY VIABILITY
  /// ============================================================
  ///
  /// Checks if a module passes policy rules.
  /// Even if a module is enabled, if its required policy
  /// rules are not allowed, it should not be rendered.
  /// ============================================================
  bool isModuleAllowed(String moduleKey) {
    // Policy-based module filtering by key prefix
    // e.g., 'marketplace' module requires 'marketplace.*' policies
    switch (moduleKey) {
      case 'marketplace':
        return engine.isAllowed(Policies.marketplaceSelling) ||
            engine.isAllowed(Policies.marketplaceBuying);
      case 'traceability':
        return engine.isAllowed(Policies.traceability) ||
            engine.isAllowed(Policies.allowTraceabilityMapping);
      case 'analytics':
        return engine.isAllowed(Policies.analytics);
      case 'ai_assistant':
        return engine.isAllowed(Policies.aiAssistant);
      case 'staff':
        return engine.isAllowed(Policies.staffManagement);
      case 'coldchain':
        return engine.isAllowed(Policies.coldChain);
      case 'logistics':
        return engine.isAllowed(Policies.logistics);
      case 'export':
        return engine.isAllowed(Policies.exportCertification);
      case 'contract_farming':
        return engine.isAllowed(Policies.contractFarming);
      case 'farm_management':
        return true; // Core module — no policy restriction
      case 'carbon_credit':
        return engine.isAllowed(Policies.allowCarbonMapping);
      default:
        return true; // No policy restriction
    }
  }

  /// ============================================================
  /// CHECK IF WORKFLOW IS ALLOWED
  /// ============================================================
  ///
  /// Returns true if workflow execution is allowed in this location.
  /// Every workflow must check this before allowing execution.
  /// ============================================================
  bool get isWorkflowAllowed =>
      engine.isAllowed(Policies.workflowExecution);

  /// ============================================================
  /// CHECK IF MARKETPLACE IS ALLOWED
  /// ============================================================
  bool get isMarketplaceSellingAllowed =>
      engine.isAllowed(Policies.marketplaceSelling);
  bool get isMarketplaceBuyingAllowed =>
      engine.isAllowed(Policies.marketplaceBuying);
  bool get isMarketplaceOrdersAllowed =>
      engine.isAllowed(Policies.marketplaceOrders);

  /// ============================================================
  /// GET MAX IMAGE UPLOAD LIMIT
  /// ============================================================
  ///
  /// Never hardcode image limits. Always use policy engine.
  /// ============================================================
  int get maxImageUploadLimit =>
      engine.getNumber(Policies.maxImageUpload);

  // ============================================================
  // SPATIAL POLICY CHECKS
  // ============================================================

  /// Whether boundary capture is allowed in this location
  bool get isBoundaryCaptureAllowed =>
      engine.isAllowed(Policies.allowBoundaryCapture);

  /// Whether area editing is allowed in this location
  bool get isAreaEditAllowed =>
      engine.isAllowed(Policies.allowAreaEdit);

  /// Whether overlap analysis is allowed in this location
  bool get isOverlapAnalysisAllowed =>
      engine.isAllowed(Policies.allowOverlapAnalysis);

  /// Whether GPS capture is allowed in this location
  bool get isGpsCaptureAllowed =>
      engine.isAllowed(Policies.allowGpsCapture);

  /// Whether carbon mapping is allowed in this location
  bool get isCarbonMappingAllowed =>
      engine.isAllowed(Policies.allowCarbonMapping);

  /// Whether traceability mapping is allowed in this location
  bool get isTraceabilityMappingAllowed =>
      engine.isAllowed(Policies.allowTraceabilityMapping);

  // ============================================================
  // PRIVATE HELPERS
  // ============================================================

  bool _isItemAllowed(PolicyFilterableItem item) {
    final requiredRules = item.requiredPolicyRules;
    if (requiredRules.isEmpty) return true; // No policy constraints
    return requiredRules.every((rule) => engine.isAllowed(rule));
  }
}

/// ============================================================
/// POLICY WORKFLOW STAGE
/// ============================================================
///
/// Defines a workflow stage with its policy rule requirement.
/// Used to filter workflow stages by location policy.
/// ============================================================
class PolicyWorkflowStage {
  /// Stage identifier
  final String stageKey;

  /// Display name
  final String displayName;

  /// Optional policy rule required for this stage
  final String? requiredPolicyRule;

  /// Whether this stage is optional (skip if policy disallows)
  final bool isOptional;

  const PolicyWorkflowStage({
    required this.stageKey,
    required this.displayName,
    this.requiredPolicyRule,
    this.isOptional = true,
  });
}
