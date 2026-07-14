/// ============================================================
/// SPATIAL SDK — DEVELOPER-FACING PUBLIC FACADE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/sdk/ = developer-facing SDK layer
///
/// The Spatial SDK is the ONLY public API for feature modules
/// to interact with spatial runtime.
///
/// ✅ Responsibilities:
///   - Expose developer-friendly spatial methods
///   - Delegate to providers and repositories
///   - Never expose SpatialEngine, providers, or repositories directly
///
/// ❌ Does NOT:
///   - Contain business logic
///   - Contain persistence logic
///   - Contain UI
///   - Import Flutter widgets
///
/// ✅ Usage:
///   ```dart
///   final spatial = ref.read(famhubSpatialSdkProvider);
///
///   // Get current state
///   final asset = spatial.currentAsset();
///   final boundary = spatial.boundary();
///   final area = spatial.area();
///
///   // Perform operations
///   await spatial.selectAsset(asset);
///   await spatial.capture();
///   await spatial.finishCapture();
///   ```
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/spatial/domain/spatial_asset.dart';
import 'package:famhub_app/core/spatial/domain/spatial_boundary.dart';
import 'package:famhub_app/core/spatial/domain/spatial_capture_session.dart';
import 'package:famhub_app/core/spatial/domain/spatial_capture_point.dart';
import 'package:famhub_app/core/spatial/domain/spatial_overlap.dart';
import 'package:famhub_app/core/spatial/application/spatial_provider.dart';
import 'package:famhub_app/core/spatial/application/spatial_engine.dart';
import 'package:famhub_app/core/spatial/application/selected_spatial_asset_provider.dart';
import 'package:famhub_app/core/spatial/infrastructure/spatial_repository.dart';

/// ============================================================
/// SPATIAL SDK
/// ============================================================
///
/// Feature modules use this instead of reading providers directly.
///
/// Usage:
///   final spatial = ref.read(famhubSpatialSdkProvider);
///
///   // Reactive watch
///   final engine = spatial.watch();
///
///   // Current asset
///   final asset = spatial.currentAsset();
///   await spatial.selectAsset(asset);
///
///   // Boundary
///   final boundary = spatial.boundary();
///   final hasBoundary = spatial.hasBoundary();
///
///   // Capture
///   await spatial.capture();
///   await spatial.finishCapture();
///
///   // Analytics
///   final area = spatial.area();
///   final perimeter = spatial.perimeter();
///
///   // Overlaps
///   final hasOverlap = spatial.hasOverlap();
/// ============================================================
class SpatialSdk {
  final Ref _ref;

  SpatialSdk(this._ref);

  // ============================================================
  // REACTIVE ENGINE
  // ============================================================

  /// Watch the spatial engine reactively.
  /// Use this in widgets that need to rebuild on spatial state changes.
  SpatialEngine watch() => _ref.watch(spatialEngineProvider);

  /// Read the spatial engine once.
  SpatialEngine read() => _ref.read(spatialEngineProvider);

  // ============================================================
  // CURRENT ASSET
  // ============================================================

  /// Get the currently selected spatial asset.
  SpatialAsset? currentAsset() =>
      _ref.read(selectedSpatialAssetProvider);

  /// Select a spatial asset to work with.
  Future<void> selectAsset(SpatialAsset asset) async {
    _ref.read(selectedSpatialAssetProvider.notifier).select(asset);

    // Load the boundary for this asset
    final repository = _ref.read(spatialRepositoryProvider);
    final boundaries = await repository.getBoundaries(asset.id);
    if (boundaries.isNotEmpty) {
      _ref.read(selectedBoundaryProvider.notifier)
          .select(boundaries.first);
    }

    // Check for active capture session
    final session =
        await repository.getActiveCaptureSession(asset.id);
    if (session != null) {
      _ref.read(activeCaptureSessionProvider.notifier).start(session);
    }
  }

  /// Clear the current asset selection.
  void clearAsset() {
    _ref.read(selectedSpatialAssetProvider.notifier).clear();
    _ref.read(selectedBoundaryProvider.notifier).clear();
    _ref.read(activeCaptureSessionProvider.notifier).clear();
  }

  // ============================================================
  // ASSET CHILDREN / HIERARCHY
  // ============================================================

  /// Get child assets for a given parent.
  Future<List<SpatialAsset>> childAssets(String parentAssetId) async {
    final repository = _ref.read(spatialRepositoryProvider);
    return repository.getChildAssets(parentAssetId);
  }

  /// Get all assets for an entity.
  Future<List<SpatialAsset>> assets(String entityId) async {
    final repository = _ref.read(spatialRepositoryProvider);
    return repository.getAssets(entityId);
  }

  // ============================================================
  // BOUNDARY
  // ============================================================

  /// Get the currently selected boundary.
  SpatialBoundary? boundary() =>
      _ref.read(selectedBoundaryProvider);

  /// Whether the current asset has a boundary.
  bool hasBoundary() => _ref.read(spatialEngineProvider).hasBoundary;

  /// Get the boundary ID.
  String? boundaryId() =>
      _ref.read(spatialEngineProvider).boundaryId;

  /// Get boundaries for a specific asset.
  Future<List<SpatialBoundary>> boundaries(String assetId) async {
    final repository = _ref.read(spatialRepositoryProvider);
    return repository.getBoundaries(assetId);
  }

  /// Upload a boundary for the current asset.
  Future<void> uploadBoundary({
    required Map<String, dynamic> geometry,
    String accuracyLevel = 'gps',
  }) async {
    final asset = currentAsset();
    if (asset == null) return;

    final repository = _ref.read(spatialRepositoryProvider);
    await repository.uploadBoundary(
      assetId: asset.id,
      geometry: geometry,
      accuracyLevel: accuracyLevel,
    );

    // Reload boundaries
    final boundaries = await repository.getBoundaries(asset.id);
    if (boundaries.isNotEmpty) {
      _ref.read(selectedBoundaryProvider.notifier)
          .select(boundaries.first);
    }
  }

  // ============================================================
  // CAPTURE
  // ============================================================

  /// Start a capture session for the current asset.
  Future<CaptureSession?> capture({
    String mode = 'manual',
  }) async {
    final asset = currentAsset();
    if (asset == null) return null;

    final repository = _ref.read(spatialRepositoryProvider);
    final session = await repository.startCapture(
      assetId: asset.id,
      mode: mode,
    );

    _ref.read(activeCaptureSessionProvider.notifier).start(session);
    return session;
  }

  /// Finish the current capture session.
  Future<void> finishCapture() async {
    final engine = _ref.read(spatialEngineProvider);
    final sessionId = engine.captureSessionId;
    if (sessionId == null) return;

    final repository = _ref.read(spatialRepositoryProvider);
    await repository.finishCapture(sessionId);

    // Update state
    final session = engine.selectedSession?.copyWith(
      status: 'completed',
    );
    if (session != null) {
      _ref.read(activeCaptureSessionProvider.notifier).complete(session);
    }
  }

  /// Cancel the current capture session.
  Future<void> cancelCapture() async {
    final engine = _ref.read(spatialEngineProvider);
    final sessionId = engine.captureSessionId;
    if (sessionId == null) return;

    final repository = _ref.read(spatialRepositoryProvider);
    await repository.cancelCapture(sessionId);
    _ref.read(activeCaptureSessionProvider.notifier).cancel();
  }

  /// Add a capture point to the current session.
  Future<CapturePoint?> addPoint({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    final engine = _ref.read(spatialEngineProvider);
    final sessionId = engine.captureSessionId;
    if (sessionId == null) return null;

    final repository = _ref.read(spatialRepositoryProvider);
    final sequence = engine.capturePointCount + 1;

    return repository.addCapturePoint(
      sessionId: sessionId,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      sequence: sequence,
    );
  }

  /// Get capture points for the current session.
  List<CapturePoint> points() =>
      _ref.read(spatialEngineProvider).capturePoints;

  /// Whether a capture session is active.
  bool hasCapture() =>
      _ref.read(spatialEngineProvider).hasCapture;

  /// Whether the capture session is complete.
  bool isCaptureComplete() =>
      _ref.read(spatialEngineProvider).isCaptureComplete;

  // ============================================================
  // OVERLAP
  // ============================================================

  /// Whether the current asset has overlaps.
  bool hasOverlap() =>
      _ref.read(spatialEngineProvider).hasOverlap;

  /// Get overlaps for the current asset.
  List<SpatialOverlap> overlaps() =>
      _ref.read(spatialEngineProvider).overlaps;

  /// Detect overlaps for the current asset.
  Future<List<SpatialOverlap>> detectOverlaps() async {
    final asset = currentAsset();
    if (asset == null) return [];

    final repository = _ref.read(spatialRepositoryProvider);
    return repository.detectOverlap(asset.id);
  }

  // ============================================================
  // ANALYTICS
  // ============================================================

  /// Calculate the area of the current boundary in hectares.
  double? area() =>
      _ref.read(spatialEngineProvider).calculateArea();

  /// Calculate the perimeter of the current boundary in meters.
  double? perimeter() =>
      _ref.read(spatialEngineProvider).calculatePerimeter();

  /// Get the area from the backend (source of truth).
  double? areaHa() =>
      _ref.read(spatialEngineProvider).currentAreaHa;

  // ============================================================
  // STATE CHECKS
  // ============================================================

  /// Whether a spatial asset is selected.
  bool hasSelectedAsset() =>
      _ref.read(spatialEngineProvider).hasSelectedAsset;

  /// Get the asset hierarchy.
  List<SpatialAsset> assetHierarchy() =>
      _ref.read(spatialEngineProvider).assetHierarchy;
}

/// ============================================================
/// PROVIDER: SPATIAL SDK
/// ============================================================
final famhubSpatialSdkProvider = Provider<SpatialSdk>((ref) {
  return SpatialSdk(ref);
});
