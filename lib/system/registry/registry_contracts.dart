/// ============================================================
/// REGISTRY CONTRACTS (PURE DECLARATIVE BLUEPRINTS)
/// ============================================================
///
/// SYSTEM/REGISTRY = SOURCE OF TRUTH CATALOG ONLY
///
/// Allowed:
/// - Static definitions only
/// - Pure Dart models
/// - Declarative constants
///
/// STRICTLY FORBIDDEN:
/// - Flutter UI widgets
/// - Riverpod providers
/// - Supabase queries or RPC calls
/// - Runtime feature evaluation logic
/// - User-specific logic
/// - Session/auth logic
/// - Dashboard rendering logic
/// - Caching or performance logic
/// - Module activation services
/// - Business workflows
/// - Event pipelines
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

/// ============================================================
/// MODULE DEFINITION BLUEPRINT
/// ============================================================
///
/// Pure static definition of a system module.
/// No runtime state, no services, no UI.
/// ============================================================
class ModuleDefinition {
  /// Unique module identifier
  final String moduleId;

  /// Human-readable display name
  final String name;

  /// Module description
  final String description;

  /// Current semantic version
  final String version;

  /// Primary entry route path
  final String entryRoute;

  /// Icon key string for presentation-layer resolution
  /// Maps to IconResolver.resolve(iconKey) in UI layer only
  final String iconKey;

  /// Display order for dashboard sorting (lower = first)
  final int displayOrder;

  /// Static metadata (configuration only, NOT runtime state)
  final Map<String, dynamic> metadata;

  /// Default enabled state (blueprint default)
  final bool isEnabledDefault;

  /// Default visibility state (blueprint default)
  final bool isVisibleDefault;

  /// Maintenance mode default
  final bool maintenanceModeDefault;

  const ModuleDefinition({
    required this.moduleId,
    required this.name,
    required this.description,
    required this.version,
    required this.entryRoute,
    this.iconKey = 'widgets',
    this.displayOrder = 999,
    this.metadata = const {},
    this.isEnabledDefault = false,
    this.isVisibleDefault = true,
    this.maintenanceModeDefault = false,
  });

  @override
  String toString() =>
      'ModuleDefinition($moduleId: $name v$version)';
}

/// ============================================================
/// FEATURE DEFINITION BLUEPRINT
/// ============================================================
///
/// Static capability flag for a module.
/// Declares what features a module offers.
/// ============================================================
class FeatureDefinition {
  /// Unique feature key
  final String featureKey;

  /// Owning module ID
  final String moduleId;

  /// Whether enabled by default
  final bool defaultEnabled;

  /// Required subscription tier (static rule)
  final String requiredTier;

  /// Feature description
  final String? description;

  const FeatureDefinition({
    required this.featureKey,
    required this.moduleId,
    required this.defaultEnabled,
    this.requiredTier = 'free',
    this.description,
  });

  @override
  String toString() =>
      'FeatureDefinition($featureKey)';
}

/// ============================================================
/// ACCESS RULE BLUEPRINT (DECLARATIVE ONLY)
/// ============================================================
///
/// Static access constraint declarations.
/// NOT runtime evaluation — evaluation happens in core/services/.
/// ============================================================
class AccessRule {
  /// Resource key this rule applies to
  final String resourceKey;

  /// Allowed roles (static role list)
  final List<String> allowedRoles;

  /// Required subscription tier
  final String requiredTier;

  /// Permission mapping definition
  final Map<String, String> permissionMappings;

  const AccessRule({
    required this.resourceKey,
    required this.allowedRoles,
    this.requiredTier = 'free',
    this.permissionMappings = const {},
  });

  @override
  String toString() =>
      'AccessRule($resourceKey)';
}

/// ============================================================
/// DEPENDENCY EDGE BLUEPRINT
/// ============================================================
///
/// Defines a directional dependency between two modules.
/// Static graph only — no runtime evaluation.
/// ============================================================
class DependencyEdge {
  /// Source module ID
  final String fromModuleId;

  /// Target module ID (depends on this module)
  final String toModuleId;

  /// Whether the dependency is required or optional
  final bool isRequired;

  const DependencyEdge({
    required this.fromModuleId,
    required this.toModuleId,
    this.isRequired = false,
  });

  @override
  String toString() =>
      'DependencyEdge($fromModuleId -> $toModuleId)';
}

/// ============================================================
/// ROUTE MAPPING BLUEPRINT (STATIC ONLY)
/// ============================================================
///
/// Static mapping from module ID to route path.
/// ============================================================
class RouteMapping {
  /// Module identifier
  final String moduleId;

  /// Route path
  final String route;

  /// Route name for named navigation
  final String? routeName;

  const RouteMapping({
    required this.moduleId,
    required this.route,
    this.routeName,
  });

  @override
  String toString() =>
      'RouteMapping($moduleId -> $route)';
}
