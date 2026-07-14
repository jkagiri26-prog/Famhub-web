/// ============================================================
/// SPATIAL PROVIDERS — RIVERPOD STATE MANAGEMENT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/application/ = spatial application layer
///
/// All spatial Riverpod providers live here.
/// Feature modules should NEVER read these directly.
/// Always use the SpatialSdk instead.
///
/// ✅ Responsibilities:
///   - Expose spatial state reactively via Riverpod
///   - Manage asset selection, boundary loading, capture state
///   - Integrate with SpatialEngine for runtime logic
///
/// ❌ Does NOT:
///   - Import Flutter widgets
///   - Contain business logic
///   - Contain UI
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/spatial/domain/spatial_asset.dart';
import 'package:famhub_app/core/spatial/domain/spatial_boundary.dart';
import 'package:famhub_app/core/spatial/domain/spatial_capture_session.dart';
import 'package:famhub_app/core/spatial/domain/spatial_capture_point.dart';
import 'package:famhub_app/core/spatial/domain/spatial_overlap.dart';
import 'package:famhub_app/core/spatial/application/spatial_engine.dart';
import 'package:famhub_app/core/spatial/application/selected_spatial_asset_provider.dart';
import 'package:famhub_app/core/spatial/infrastructure/spatial_repository.dart';

// ============================================================
// REPOSITORY PROVIDER
// ============================================================

/// The spatial repository provider.
/// Injected during bootstrap; defaults to a future Supabase implementation.
final spatialRepositoryProvider =
    Provider<SpatialRepository>((ref) {
  throw UnimplementedError(
    'SpatialRepository not initialized. '
    'Call bootstrapSpatial() during app startup.',
  );
});

// ============================================================
// ASSET PROVIDERS
// ============================================================

/// All spatial assets for the current context.
final spatialAssetsProvider =
    FutureProvider.family<List<SpatialAsset>, String>(
  (ref, entityId) async {
    final repository = ref.read(spatialRepositoryProvider);
    return repository.getAssets(entityId);
  },
);

/// A single spatial asset by ID.
final spatialAssetProvider =
    FutureProvider.family<SpatialAsset?, String>(
  (ref, assetId) async {
    final repository = ref.read(spatialRepositoryProvider);
    return repository.getAsset(assetId);
  },
);

// ============================================================
// BOUNDARY PROVIDERS
// ============================================================

/// Boundaries for a specific asset.
final assetBoundaryProvider =
    FutureProvider.family<List<SpatialBoundary>, String>(
  (ref, assetId) async {
    final repository = ref.read(spatialRepositoryProvider);
    return repository.getBoundaries(assetId);
  },
);

/// The currently selected boundary.
final selectedBoundaryProvider =
    NotifierProvider<BoundaryNotifier, SpatialBoundary?>(
  BoundaryNotifier.new,
);

class BoundaryNotifier extends Notifier<SpatialBoundary?> {
  @override
  SpatialBoundary? build() => null;

  void select(SpatialBoundary boundary) => state = boundary;
  void clear() => state = null;
}

// ============================================================
// CAPTURE SESSION PROVIDERS
// ============================================================

/// Capture sessions for a specific asset.
final captureSessionProvider =
    FutureProvider.family<List<CaptureSession>, String>(
  (ref, assetId) async {
    final repository = ref.read(spatialRepositoryProvider);
    return repository.getCaptureSessions(assetId);
  },
);

/// The currently active capture session.
final activeCaptureSessionProvider =
    NotifierProvider<CaptureSessionNotifier, CaptureSession?>(
  CaptureSessionNotifier.new,
);

class CaptureSessionNotifier extends Notifier<CaptureSession?> {
  @override
  CaptureSession? build() => null;

  void start(CaptureSession session) => state = session;
  void complete(CaptureSession session) => state = session;
  void cancel() => state = null;
  void clear() => state = null;
}

// ============================================================
// CAPTURE POINT PROVIDERS
// ============================================================

/// Capture points for a specific session.
final capturePointsProvider =
    FutureProvider.family<List<CapturePoint>, String>(
  (ref, sessionId) async {
    final repository = ref.read(spatialRepositoryProvider);
    return repository.getCapturePoints(sessionId);
  },
);

// ============================================================
// OVERLAP PROVIDERS
// ============================================================

/// Spatial overlaps for a specific asset.
final spatialOverlapProvider =
    FutureProvider.family<List<SpatialOverlap>, String>(
  (ref, assetId) async {
    final repository = ref.read(spatialRepositoryProvider);
    return repository.getOverlaps(assetId);
  },
);

// ============================================================
// ENGINE PROVIDER
// ============================================================

/// The spatial engine — provides runtime logic over spatial state.
final spatialEngineProvider = Provider<SpatialEngine>((ref) {
  final currentAsset = ref.watch(selectedSpatialAssetProvider);
  final selectedBoundary = ref.watch(selectedBoundaryProvider);
  final selectedSession = ref.watch(activeCaptureSessionProvider);

  // Capture points from the selected session
  final capturePointsAsync = selectedSession != null
      ? ref.watch(capturePointsProvider(selectedSession.id))
      : null;
  final capturePoints = capturePointsAsync?.value ?? [];

  // Overlaps from the current asset
  final overlapsAsync = currentAsset != null
      ? ref.watch(spatialOverlapProvider(currentAsset.id))
      : null;
  final overlaps = overlapsAsync?.value ?? [];

  // All assets (empty for now; can be loaded from context)
  final allAssets = <SpatialAsset>[];

  return SpatialEngine(
    currentAsset: currentAsset,
    selectedBoundary: selectedBoundary,
    selectedSession: selectedSession,
    capturePoints: capturePoints,
    overlaps: overlaps,
    allAssets: allAssets,
  );
});
