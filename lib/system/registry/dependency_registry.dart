// ignore: dangling_library_doc_comments
/// ============================================================
/// DEPENDENCY REGISTRY (PURE STATIC GRAPH)
/// ============================================================
///
/// SYSTEM/REGISTRY = SOURCE OF TRUTH CATALOG ONLY
///
/// Static module dependency graph definitions.
/// Declares which modules depend on which other modules.
///
/// ✅ Allowed:
///   - Static dependency edge declarations
///   - Module dependency graph (static only)
///
/// ❌ Forbidden:
///   - Runtime dependency resolution logic
///   - Async/service/provider calls
///   - UI/widget imports
/// ============================================================

import 'registry_contracts.dart';

/// ============================================================
/// DEPENDENCY REGISTRY — STATIC MODULE DEPENDENCY GRAPH
/// ============================================================
///
/// Defines the dependency relationships between modules.
///
/// NOTE: Dependencies are directional.
///   - If module A depends on module B, then B must be
///     initialized/available before A can function.
///
/// 🧠 USAGE:
///   - Used by module_control to determine initialization order
///   - Used by dashboard_engine for composition ordering
///   - Used by services for runtime dependency validation
/// ============================================================
class DependencyRegistry {
  /// ============================================================
  /// ALL DEPENDENCY EDGES (STATIC GRAPH)
  /// ============================================================
  static const List<DependencyEdge> edges = [
    // ── Farm Management depends on Profile ──────
    DependencyEdge(
      fromModuleId: 'farm_management',
      toModuleId: 'profile',
      isRequired: true,
    ),

    // ── Marketplace depends on Profile and Farm ──
    DependencyEdge(
      fromModuleId: 'marketplace',
      toModuleId: 'profile',
      isRequired: true,
    ),
    DependencyEdge(
      fromModuleId: 'marketplace',
      toModuleId: 'farm_management',
      isRequired: false,
    ),

    // ── Analytics depends on Farm Management ─────
    DependencyEdge(
      fromModuleId: 'analytics',
      toModuleId: 'farm_management',
      isRequired: true,
    ),

    // ── Financing depends on Profile ─────────────
    DependencyEdge(
      fromModuleId: 'financing',
      toModuleId: 'profile',
      isRequired: true,
    ),
    DependencyEdge(
      fromModuleId: 'financing',
      toModuleId: 'farm_management',
      isRequired: false,
    ),

    // ── Logistics depends on Marketplace ─────────
    DependencyEdge(
      fromModuleId: 'logistics',
      toModuleId: 'marketplace',
      isRequired: false,
    ),
    DependencyEdge(
      fromModuleId: 'logistics',
      toModuleId: 'profile',
      isRequired: true,
    ),

    // ── Traceability depends on Farm Management ──
    DependencyEdge(
      fromModuleId: 'traceability',
      toModuleId: 'farm_management',
      isRequired: true,
    ),

    // ── Carbon Credit depends on Farm Management ─
    DependencyEdge(
      fromModuleId: 'carbon_credit',
      toModuleId: 'farm_management',
      isRequired: true,
    ),

    // ── Referral Hub depends on Profile ──────────
    DependencyEdge(
      fromModuleId: 'referral_hub',
      toModuleId: 'profile',
      isRequired: true,
    ),
    DependencyEdge(
      fromModuleId: 'referral_hub',
      toModuleId: 'marketplace',
      isRequired: false,
    ),
  ];

  /// ============================================================
  /// PURE LOOKUP HELPERS
  /// ============================================================

  /// Get all dependencies for a given module.
  static List<DependencyEdge> dependenciesOf(String moduleId) {
    final result = <DependencyEdge>[];
    for (final edge in edges) {
      if (edge.fromModuleId == moduleId) {
        result.add(edge);
      }
    }
    return result;
  }

  /// Get all dependents (modules that depend on the given module).
  static List<DependencyEdge> dependentsOf(String moduleId) {
    final result = <DependencyEdge>[];
    for (final edge in edges) {
      if (edge.toModuleId == moduleId) {
        result.add(edge);
      }
    }
    return result;
  }

  /// Get required dependencies for a module.
  static List<DependencyEdge> requiredDependenciesOf(String moduleId) {
    final result = <DependencyEdge>[];
    for (final edge in edges) {
      if (edge.fromModuleId == moduleId && edge.isRequired) {
        result.add(edge);
      }
    }
    return result;
  }
}
