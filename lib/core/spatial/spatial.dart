/// ============================================================
/// SPATIAL RUNTIME — BARREL EXPORT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/ = spatial runtime layer
///
/// The Spatial Runtime manages spatial assets, boundaries,
/// GPS capture, overlap detection, and spatial analytics.
///
/// It does NOT own the GIS system.
/// The backend already owns:
///   spatial.spatial_assets
///   spatial.spatial_boundaries
///   spatial.spatial_capture_sessions
///   spatial.spatial_capture_points
///   spatial.spatial_overlaps
///
/// The frontend is a CONSUMER of this runtime.
///
/// Spatial is a core runtime service alongside:
///   Organization, Capability, Policy, Access, Workspace
///
/// ✅ Design Principles:
///   - Pure Dart domain models — no Flutter
///   - Immutable state everywhere
///   - Abstract repository — no direct PostGIS queries
///   - SpatialEngine for runtime logic — no database dependency
///   - SpatialSdk for feature developers — never access providers
///   - Composition bridge — no hardcoded module lists
///
/// ✅ Bootstrap order:
///   Capabilities → Policies → SPATIAL → Access → Workspace → Dashboard
///
/// 🚫 No module should ever query PostGIS directly.
///    All spatial data flows through SpatialRepository.
/// ============================================================
library;

// ── Domain ──
export 'domain/spatial_asset.dart';
export 'domain/spatial_boundary.dart';
export 'domain/spatial_capture_session.dart';
export 'domain/spatial_capture_point.dart';
export 'domain/spatial_overlap.dart';

// ── Application ──
export 'application/spatial_engine.dart';
export 'application/spatial_provider.dart';

// ── Infrastructure ──
export 'infrastructure/spatial_repository.dart';
export 'infrastructure/supabase_spatial_repository.dart';

// ── Composition Bridge ──
export 'composition/spatial_composition_bridge.dart';

// ── SDK ──
export 'sdk/spatial_sdk.dart';

// ── Bootstrap ──
export 'bootstrap/spatial_bootstrap.dart';
