/// ============================================================
/// SPATIAL REPOSITORY — ABSTRACT CONTRACT
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/infrastructure/ = spatial data access
///
/// Abstract contract for spatial data access.
/// Enables clean future backend integration without
/// changing the domain or application layers.
///
/// No module should ever query PostGIS directly.
/// All spatial data access flows through this contract.
///
/// ✅ Responsibilities:
///   - Define the contract for spatial data operations
///   - Support CRUD operations for all spatial entities
///   - Support capture session lifecycle
///
/// ❌ Does NOT:
///   - Import Flutter
///   - Import any UI framework
///   - Contain business logic
///   - Contain state
/// ============================================================
library;

import 'package:famhub_app/core/spatial/domain/spatial_asset.dart';
import 'package:famhub_app/core/spatial/domain/spatial_boundary.dart';
import 'package:famhub_app/core/spatial/domain/spatial_capture_session.dart';
import 'package:famhub_app/core/spatial/domain/spatial_capture_point.dart';
import 'package:famhub_app/core/spatial/domain/spatial_overlap.dart';

/// ============================================================
/// SPATIAL REPOSITORY
/// ============================================================
///
/// Abstract contract for all spatial data operations.
/// Every spatial data query must go through this repository.
///
/// No module should ever query PostGIS directly.
/// ============================================================
abstract class SpatialRepository {
  // ============================================================
  // SPATIAL ASSETS
  // ============================================================

  /// Get all spatial assets for a given entity.
  Future<List<SpatialAsset>> getAssets(String entityId);

  /// Get a single spatial asset by ID.
  Future<SpatialAsset?> getAsset(String id);

  /// Get child assets for a given parent asset.
  Future<List<SpatialAsset>> getChildAssets(String parentAssetId);

  /// Get assets by type for a given entity.
  Future<List<SpatialAsset>> getAssetsByType(
    String entityId,
    String assetType,
  );

  // ============================================================
  // SPATIAL BOUNDARIES
  // ============================================================

  /// Get boundaries for a specific asset.
  Future<List<SpatialBoundary>> getBoundaries(String assetId);

  /// Upload a boundary for an asset.
  Future<void> uploadBoundary({
    required String assetId,
    required Map<String, dynamic> geometry,
    String accuracyLevel = 'gps',
  });

  // ============================================================
  // CAPTURE SESSIONS
  // ============================================================

  /// Get all capture sessions for an asset.
  Future<List<CaptureSession>> getCaptureSessions(String assetId);

  /// Get the active capture session for an asset, if any.
  Future<CaptureSession?> getActiveCaptureSession(String assetId);

  /// Start a new capture session for an asset.
  Future<CaptureSession> startCapture({
    required String assetId,
    String mode = 'manual',
  });

  /// Mark a capture session as completed.
  Future<void> finishCapture(String sessionId);

  /// Cancel a capture session.
  Future<void> cancelCapture(String sessionId);

  // ============================================================
  // CAPTURE POINTS
  // ============================================================

  /// Get all capture points for a session.
  Future<List<CapturePoint>> getCapturePoints(String sessionId);

  /// Add a capture point to a session.
  Future<CapturePoint> addCapturePoint({
    required String sessionId,
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    int sequence = 0,
  });

  // ============================================================
  // SPATIAL OVERLAPS
  // ============================================================

  /// Get overlaps involving a specific asset.
  Future<List<SpatialOverlap>> getOverlaps(String assetId);

  /// Detect and return overlaps for a given asset.
  Future<List<SpatialOverlap>> detectOverlap(String assetId);
}
