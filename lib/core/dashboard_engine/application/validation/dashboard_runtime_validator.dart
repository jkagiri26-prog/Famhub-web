/// ============================================================
/// 
/// DASHBOARD RUNTIME VALIDATOR (APPLICATION)
/// ============================================================
///
/// Validates each CompositionNode against 8 conditions BEFORE rendering.
///
/// CONDITIONS CHECKED (in order):
/// 1. module exists     → ModuleRegistry
/// 2. route exists      → RouteRegistry
/// 3. widget exists     → WidgetBuilderRegistry
/// 4. dependency sat.   → DependencyRegistry
/// 5. feature enabled   → FeatureRegistry + access service
/// 6. access allowed    → AccessRegistry
/// 7. subscription ok   → Subscription tier check
/// 8. maintenance off   → Maintenance mode check
///
/// BEHAVIOR:
/// - Skips invalid node gracefully
/// - Returns degraded UI instructions
/// - Logs all failures
/// - NEVER crashes the runtime
/// ============================================================

// ignore_for_file: library_prefixes
library;

import 'package:famhub_app/core/dashboard_engine/domain/models/composition_node.dart';
import 'package:famhub_app/core/dashboard_engine/application/validation/runtime_validation_failure.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_builder_registry.dart';
import 'package:famhub_app/system/registry/module_registry.dart';
import 'package:famhub_app/system/registry/feature_registry.dart';
import 'package:famhub_app/system/registry/access_registry.dart';
import 'package:famhub_app/system/registry/dependency_registry.dart';
import 'package:famhub_app/system/registry/route_registry.dart';

/// Result of validating a single node
class NodeValidationResult {
  final bool isValid;
  final RuntimeValidationFailure? failure;
  final CompositionNode node;

  const NodeValidationResult({
    required this.isValid,
    this.failure,
    required this.node,
  });

  /// Create a valid result
  factory NodeValidationResult.valid(CompositionNode node) =>
      NodeValidationResult(isValid: true, node: node);

  /// Create an invalid result with failure
  factory NodeValidationResult.invalid(
    CompositionNode node,
    RuntimeValidationFailure failure,
  ) =>
      NodeValidationResult(isValid: false, failure: failure, node: node);
}

/// Aggregate validation result for a full snapshot
class DashboardValidationResult {
  final List<NodeValidationResult> nodeResults;
  final DateTime validatedAt;
  final List<RuntimeValidationFailure> allFailures;

  const DashboardValidationResult({
    required this.nodeResults,
    required this.validatedAt,
    required this.allFailures,
  });

  /// Nodes that passed validation
  List<CompositionNode> get validNodes =>
      nodeResults.where((r) => r.isValid).map((r) => r.node).toList();

  /// Nodes that failed validation
  List<NodeValidationResult> get invalidResults =>
      nodeResults.where((r) => !r.isValid).toList();

  bool get hasFailures => allFailures.isNotEmpty;
  bool get allValid => allFailures.isEmpty;
}

/// ============================================================
/// MAIN VALIDATOR
/// ============================================================
class DashboardRuntimeValidator {
  final String? userRole;
  final String? userTier;

  /// Maintenance module IDs (modules currently in maintenance mode).
  /// Provided by ModuleRuntimeState or external maintenance service.
  final Set<String> maintenanceModules;

  const DashboardRuntimeValidator({
    this.userRole,
    this.userTier,
    this.maintenanceModules = const {},
  });

  /// ============================================================
  /// VALIDATE A SINGLE NODE AGAINST ALL 8 CONDITIONS
  /// ============================================================
  NodeValidationResult validateNode(CompositionNode node) {
    final moduleKey = node.moduleKey;
    final widgetKey = node.widgetKey;

    // ── 1. MODULE EXISTS ──
    final module = ModuleRegistry.byId(moduleKey);
    if (module == null) {
      return NodeValidationResult.invalid(
        node,
        RuntimeValidationFailure(
          nodeId: node.id,
          moduleKey: moduleKey,
          widgetKey: widgetKey,
          type: ValidationFailureType.moduleNotFound,
          message: 'Module "$moduleKey" not found in ModuleRegistry',
        ),
      );
    }

    // ── 2. ROUTE EXISTS ──
    final route = module.entryRoute;
    final routeEntry = RouteRegistry.forRoute(route);
    if (routeEntry == null) {
      return NodeValidationResult.invalid(
        node,
        RuntimeValidationFailure(
          nodeId: node.id,
          moduleKey: moduleKey,
          widgetKey: widgetKey,
          type: ValidationFailureType.routeNotFound,
          message: 'Route "$route" for module "$moduleKey" not found in RouteRegistry',
        ),
      );
    }

    // ── 3. WIDGET EXISTS ──
    if (!WidgetBuilderRegistry.isRegistered(widgetKey)) {
      return NodeValidationResult.invalid(
        node,
        RuntimeValidationFailure(
          nodeId: node.id,
          moduleKey: moduleKey,
          widgetKey: widgetKey,
          type: ValidationFailureType.widgetNotFound,
          message: 'Widget "$widgetKey" not registered in WidgetBuilderRegistry',
        ),
      );
    }

    // ── 4. DEPENDENCY SATISFIED ──
    final requiredDeps = DependencyRegistry.requiredDependenciesOf(moduleKey);
    for (final dep in requiredDeps) {
      final depModule = ModuleRegistry.byId(dep.toModuleId);
      if (depModule == null) {
        return NodeValidationResult.invalid(
          node,
          RuntimeValidationFailure(
            nodeId: node.id,
            moduleKey: moduleKey,
            widgetKey: widgetKey,
            type: ValidationFailureType.dependencyUnsatisfied,
            message: 'Required dependency "${dep.toModuleId}" for module "$moduleKey" not found',
          ),
        );
      }
    }

    // ── 5. FEATURE ENABLED ──
    // Check if the widget key maps to a feature
    final feature = FeatureRegistry.byKey(widgetKey);
    if (feature != null && !feature.defaultEnabled) {
      // Feature is defined but not enabled by default
      // This is a soft check — actual runtime feature gating
      // is handled by the feature gate service. But we flag it.
      return NodeValidationResult.invalid(
        node,
        RuntimeValidationFailure(
          nodeId: node.id,
          moduleKey: moduleKey,
          widgetKey: widgetKey,
          type: ValidationFailureType.featureDisabled,
          message: 'Feature "$widgetKey" is not enabled for module "$moduleKey"',
        ),
      );
    }

    // ── 6. ACCESS ALLOWED ──
    if (userRole != null) {
      final accessRule = AccessRegistry.forResource(moduleKey);
      if (accessRule != null &&
          !accessRule.allowedRoles.contains(userRole) &&
          !accessRule.allowedRoles.contains('*')) {
        return NodeValidationResult.invalid(
          node,
          RuntimeValidationFailure(
            nodeId: node.id,
            moduleKey: moduleKey,
            widgetKey: widgetKey,
            type: ValidationFailureType.accessDenied,
            message: 'Role "$userRole" not allowed for resource "$moduleKey"',
          ),
        );
      }
    }

    // ── 7. SUBSCRIPTION ALLOWED ──
    if (userTier != null && feature != null) {
      // Compare tiers — this is a simplified check
      // Full subscription validation is handled by the billing service
      final tierOrder = ['free', 'basic', 'premium', 'enterprise'];
      final userTierIndex = tierOrder.indexOf(userTier!);
      final requiredTierIndex = tierOrder.indexOf(feature.requiredTier);
      if (userTierIndex >= 0 && requiredTierIndex >= 0 && userTierIndex < requiredTierIndex) {
        return NodeValidationResult.invalid(
          node,
          RuntimeValidationFailure(
            nodeId: node.id,
            moduleKey: moduleKey,
            widgetKey: widgetKey,
            type: ValidationFailureType.subscriptionNotAllowed,
            message: 'Tier "$userTier" insufficient for feature "$widgetKey" (requires ${feature.requiredTier})',
          ),
        );
      }
    }

    // ── 8. MAINTENANCE MODE OFF ──
    // Checks if the module is in maintenance mode via the runtime state.
    if (maintenanceModules.contains(moduleKey)) {
      return NodeValidationResult.invalid(
        node,
        RuntimeValidationFailure(
          nodeId: node.id,
          moduleKey: moduleKey,
          widgetKey: widgetKey,
          type: ValidationFailureType.maintenanceModeOn,
          message: 'Module "$moduleKey" is currently in maintenance mode',
        ),
      );
    }

    return NodeValidationResult.valid(node);
  }

  /// ============================================================
  /// VALIDATE ALL NODES IN A LIST
  /// ============================================================
  DashboardValidationResult validateAll(List<CompositionNode> nodes) {
    final results = <NodeValidationResult>[];
    final allFailures = <RuntimeValidationFailure>[];

    for (final node in nodes) {
      final result = validateNode(node);
      results.add(result);
      if (!result.isValid && result.failure != null) {
        allFailures.add(result.failure!);
      }
    }

    return DashboardValidationResult(
      nodeResults: results,
      validatedAt: DateTime.now(),
      allFailures: allFailures,
    );
  }
}
