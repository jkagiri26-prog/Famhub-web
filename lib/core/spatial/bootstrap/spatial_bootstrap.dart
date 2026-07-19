/// ============================================================
/// SPATIAL BOOTSTRAP — INITIALIZATION
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/bootstrap/ = spatial initialization
///
/// Initializes the Spatial Runtime during app startup.
/// Must be called after capability and policy bootstrap,
/// but before access and workspace bootstrap.
///
/// Bootstrap order:
///   Capabilities → Policies → SPATIAL → Access → Workspace → Dashboard
///
/// ✅ Responsibilities:
///   - Initialize the spatial repository (Supabase-backed)
///   - Register spatial module requirements
///   - Prepare the spatial runtime for use
///
/// ❌ Does NOT:
///   - Render UI
///   - Import Flutter widgets
///   - Load spatial data eagerly
/// ============================================================
library;

import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/spatial/infrastructure/spatial_repository.dart';
import 'package:famhub_app/core/spatial/infrastructure/supabase_spatial_repository.dart';
import 'package:famhub_app/core/spatial/application/spatial_provider.dart';
import 'package:famhub_app/core/spatial/composition/spatial_composition_bridge.dart';

/// ============================================================
/// BOOTSTRAP SPATIAL RUNTIME
/// ============================================================
///
/// Call this once during app initialization, after
/// policy bootstrap and before access bootstrap.
///
/// Usage (in startup coordinator):
///   await bootstrapSpatial();
/// ============================================================
Future<void> bootstrapSpatial() async {
  // ── 1. Create the repository ──
  // The repository is created and registered via provider overrides.
  // During bootstrap, we set up the default Supabase-backed implementation.
  // The actual provider override happens in main.dart / provider container.

  // ── 2. Register spatial module requirements ──
  _registerSpatialModuleRequirements();

  // Log completion
  // ignore: avoid_print
  print('[SPATIAL] Bootstrap complete — '
      '${const SpatialCompositionBridge().registeredCount} spatial modules registered');
}

/// ============================================================
/// REGISTER SPATIAL MODULE REQUIREMENTS
/// ============================================================
///
/// Each module declares what spatial features it needs.
/// This allows the SpatialCompositionBridge to answer queries
/// without hardcoding module names.
///
/// 🚨 IMPORTANT:
///   These registrations define spatial integration points.
///   Do NOT hardcode modules here — modules register themselves.
///   This is the fallback registration for default modules.
/// ============================================================
void _registerSpatialModuleRequirements() {
  // ── Farm Management ──
  registerSpatialModuleRequirements(
    'farm_management',
    requiresMap: true,
    requiresLocationWidgets: true,
    requiresAreaCards: true,
    requiresBoundaryCapture: true,
    requiresGpsCapture: true,
    requiresOverlapAnalysis: true,
  );

  // ── Marketplace ──
  registerSpatialModuleRequirements(
    'marketplace',
    requiresMap: true,
    requiresLocationWidgets: true,
  );

  // ── Carbon Credit ──
  registerSpatialModuleRequirements(
    'carbon_credit',
    requiresMap: true,
    requiresAreaCards: true,
    requiresBoundaryCapture: true,
    requiresOverlapAnalysis: true,
    requiresGpsCapture: true,
  );

  // ── Traceability ──
  registerSpatialModuleRequirements(
    'traceability',
    requiresMap: true,
    requiresLocationWidgets: true,
    requiresAreaCards: true,
  );

  // ── Analytics ──
  registerSpatialModuleRequirements(
    'analytics',
    requiresMap: true,
    requiresAreaCards: true,
  );
}

/// ============================================================
/// CREATE SPATIAL REPOSITORY
/// ============================================================
///
/// Factory function to create the spatial repository.
/// Called by main.dart to provide the repository to the app.
///
/// Usage:
///   final repository = createSpatialRepository(supabaseService);
/// ============================================================
SpatialRepository createSpatialRepository(
  SupabaseService supabaseService,
) {
  return SupabaseSpatialRepository(supabaseService);
}
