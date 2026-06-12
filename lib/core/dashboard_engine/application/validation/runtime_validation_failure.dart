/// ============================================================
/// RUNTIME VALIDATION FAILURE (DOMAIN)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/validation/
///
/// Represents a single validation failure for a dashboard node.
///
/// ✅ Used by DashboardRuntimeValidator to report issues
/// ✅ Logged but NEVER crashes runtime
/// ============================================================

// ignore_for_file: library_prefixes
library;

enum ValidationFailureType {
  moduleNotFound,
  routeNotFound,
  widgetNotFound,
  dependencyUnsatisfied,
  featureDisabled,
  accessDenied,
  subscriptionNotAllowed,
  maintenanceModeOn,
}

class RuntimeValidationFailure {
  final String nodeId;
  final String moduleKey;
  final String widgetKey;
  final ValidationFailureType type;
  final String message;

  const RuntimeValidationFailure({
    required this.nodeId,
    required this.moduleKey,
    required this.widgetKey,
    required this.type,
    required this.message,
  });

  @override
  String toString() => '[${type.name}] $moduleKey/$widgetKey: $message';
}
