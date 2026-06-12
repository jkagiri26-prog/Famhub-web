/// ============================================================
/// MODULE CONTRACT (PURE ABSTRACT DEFINITION)
/// ============================================================
///
/// SYSTEM/MODULES_CONTROL = SYSTEM GOVERNANCE LAYER
///
/// Pure abstract contract for module definitions.
/// Contains NO Flutter/UI references.
///
/// ✅ Allowed:
///   - Abstract contracts
///   - Pure Dart interfaces
///
/// ❌ Forbidden:
///   - Widget/UI types
///   - Runtime logic
///   - Provider imports
/// ============================================================

/// ============================================================
/// APP MODULE CONTRACT
/// ============================================================
///
/// Defines the pure contract every module must implement.
/// No UI types — build() method moved to feature layer.
/// ============================================================
abstract class AppModule {
  /// Identity
  String get name;
  String get route;

  /// Optional grouping metadata
  String? get group => null;

  /// Role access control (static role list)
  List<String> get allowedRoles;

  /// Widget keys this module exposes to dashboard engine
  List<String> get dashboardWidgets;
}