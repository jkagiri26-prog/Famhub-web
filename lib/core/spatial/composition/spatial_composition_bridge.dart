/// ============================================================
/// SPATIAL COMPOSITION BRIDGE — MODULE INTEGRATION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/composition/ = composition integration
///
/// This bridge integrates Spatial runtime into the module
/// composition system. It answers which modules need spatial
/// features without hardcoding module names.
///
/// ✅ Responsibilities:
///   - Determine which modules expose map views
///   - Determine which widgets display location data
///   - Determine which dashboard cards show area information
///   - Determine which workflows require boundary capture
///   - Filter spatial features based on module composition
///
/// ❌ Does NOT:
///   - Render UI
///   - Import Flutter widgets
///   - Hardcode module lists
///
/// ✅ Design:
///   Modules declare their spatial requirements through
///   a registration system rather than hardcoded checks.
///   This allows new modules to integrate spatial features
///   without modifying this bridge.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ============================================================
/// SPATIAL MODULE REQUIREMENT
/// ============================================================
///
/// Defines what spatial features a module requires.
/// Modules register their requirements during bootstrap.
/// ============================================================
class SpatialModuleRequirement {
  /// The module key (e.g., 'farm_management', 'marketplace')
  final String moduleKey;

  /// Whether this module exposes an interactive map
  final bool requiresMap;

  /// Whether this module displays location-based widgets
  final bool requiresLocationWidgets;

  /// Whether this module uses dashboard cards with area data
  final bool requiresAreaCards;

  /// Whether this module has workflows that need boundary capture
  final bool requiresBoundaryCapture;

  /// Whether this module uses overlap analysis
  final bool requiresOverlapAnalysis;

  /// Whether this module uses GPS capture
  final bool requiresGpsCapture;

  const SpatialModuleRequirement({
    required this.moduleKey,
    this.requiresMap = false,
    this.requiresLocationWidgets = false,
    this.requiresAreaCards = false,
    this.requiresBoundaryCapture = false,
    this.requiresOverlapAnalysis = false,
    this.requiresGpsCapture = false,
  });
}

/// ============================================================
/// SPATIAL MODULE REQUIREMENT STORAGE
/// ============================================================
///
/// Stores spatial requirements declared by each module.
/// No hardcoded module lists — modules register themselves.
/// ============================================================
final Map<String, SpatialModuleRequirement> _spatialModuleRequirements =
    {};

/// ============================================================
/// REGISTER SPATIAL MODULE REQUIREMENTS
/// ============================================================
///
/// Called by modules during initialization to declare their
/// spatial feature requirements.
///
/// Usage:
///   registerSpatialModuleRequirements(
///     'farm_management',
///     requiresMap: true,
///     requiresBoundaryCapture: true,
///     requiresAreaCards: true,
///   );
///
///   registerSpatialModuleRequirements(
///     'carbon_credit',
///     requiresMap: true,
///     requiresOverlapAnalysis: true,
///   );
/// ============================================================
void registerSpatialModuleRequirements(
  String moduleKey, {
  bool requiresMap = false,
  bool requiresLocationWidgets = false,
  bool requiresAreaCards = false,
  bool requiresBoundaryCapture = false,
  bool requiresOverlapAnalysis = false,
  bool requiresGpsCapture = false,
}) {
  _spatialModuleRequirements[moduleKey] = SpatialModuleRequirement(
    moduleKey: moduleKey,
    requiresMap: requiresMap,
    requiresLocationWidgets: requiresLocationWidgets,
    requiresAreaCards: requiresAreaCards,
    requiresBoundaryCapture: requiresBoundaryCapture,
    requiresOverlapAnalysis: requiresOverlapAnalysis,
    requiresGpsCapture: requiresGpsCapture,
  );
}

/// ============================================================
/// SPATIAL COMPOSITION BRIDGE
/// ============================================================
///
/// Pure query bridge. Takes module requirements and answers
/// spatial integration questions.
///
/// No Flutter, no UI, no state.
/// ============================================================
class SpatialCompositionBridge {
  const SpatialCompositionBridge();

  // ============================================================
  // MODULE QUERIES
  // ============================================================

  /// Get all modules that require an interactive map.
  List<String> get modulesWithMaps {
    return _spatialModuleRequirements.entries
        .where((e) => e.value.requiresMap)
        .map((e) => e.key)
        .toList();
  }

  /// Get all modules that require location widgets.
  List<String> get modulesWithLocationWidgets {
    return _spatialModuleRequirements.entries
        .where((e) => e.value.requiresLocationWidgets)
        .map((e) => e.key)
        .toList();
  }

  /// Get all modules that require area dashboard cards.
  List<String> get modulesWithAreaCards {
    return _spatialModuleRequirements.entries
        .where((e) => e.value.requiresAreaCards)
        .map((e) => e.key)
        .toList();
  }

  /// Get all modules that require boundary capture workflows.
  List<String> get modulesWithBoundaryCapture {
    return _spatialModuleRequirements.entries
        .where((e) => e.value.requiresBoundaryCapture)
        .map((e) => e.key)
        .toList();
  }

  /// Get all modules that require overlap analysis.
  List<String> get modulesWithOverlapAnalysis {
    return _spatialModuleRequirements.entries
        .where((e) => e.value.requiresOverlapAnalysis)
        .map((e) => e.key)
        .toList();
  }

  /// Get all modules that require GPS capture.
  List<String> get modulesWithGpsCapture {
    return _spatialModuleRequirements.entries
        .where((e) => e.value.requiresGpsCapture)
        .map((e) => e.key)
        .toList();
  }

  // ============================================================
  // INDIVIDUAL MODULE QUERIES
  // ============================================================

  /// Whether a specific module requires a map view.
  bool hasMap(String moduleKey) {
    return _spatialModuleRequirements[moduleKey]?.requiresMap ?? false;
  }

  /// Whether a specific module displays location widgets.
  bool hasLocationWidgets(String moduleKey) {
    return _spatialModuleRequirements[moduleKey]
            ?.requiresLocationWidgets ??
        false;
  }

  /// Whether a specific module shows area dashboard cards.
  bool hasAreaCards(String moduleKey) {
    return _spatialModuleRequirements[moduleKey]?.requiresAreaCards ??
        false;
  }

  /// Whether a specific module has boundary capture workflows.
  bool hasBoundaryCapture(String moduleKey) {
    return _spatialModuleRequirements[moduleKey]
            ?.requiresBoundaryCapture ??
        false;
  }

  /// Whether a specific module uses overlap analysis.
  bool hasOverlapAnalysis(String moduleKey) {
    return _spatialModuleRequirements[moduleKey]
            ?.requiresOverlapAnalysis ??
        false;
  }

  /// Whether a specific module uses GPS capture.
  bool hasGpsCapture(String moduleKey) {
    return _spatialModuleRequirements[moduleKey]?.requiresGpsCapture ??
        false;
  }

  /// Get the full requirement for a module.
  SpatialModuleRequirement? requirementFor(String moduleKey) {
    return _spatialModuleRequirements[moduleKey];
  }

  /// Get all registered spatial module keys.
  List<String> get registeredModules =>
      _spatialModuleRequirements.keys.toList();

  /// Number of registered modules
  int get registeredCount => _spatialModuleRequirements.length;

  /// Clear all registrations (for testing).
  void clearRegistrations() {
    _spatialModuleRequirements.clear();
  }
}

/// ============================================================
/// PROVIDER: SPATIAL COMPOSITION BRIDGE
/// ============================================================
///
/// Exposes the SpatialCompositionBridge as a singleton provider.
/// ============================================================
final spatialCompositionBridgeProvider =
    Provider<SpatialCompositionBridge>((ref) {
  return const SpatialCompositionBridge();
});
