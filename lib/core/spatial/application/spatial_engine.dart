/// ============================================================
/// SPATIAL ENGINE — PURE DART RUNTIME LOGIC
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/application/ = spatial application layer
///
/// The Spatial Engine is the SINGLE entry point for all
/// spatial runtime logic in the application.
///
/// ✅ Responsibilities:
///   - Track current asset, boundary, session state
///   - Calculate area and perimeter from boundary geometry
///   - Check boundary existence, overlaps, capture completeness
///   - Pure Dart — no Flutter, no database, no UI
///
/// ❌ Does NOT:
///   - Perform database operations (use SpatialRepository)
///   - Import Flutter
///   - Contain UI
///   - Import Riverpod
///
/// ✅ Architecture:
///   The engine is created by SpatialEngineProvider (Riverpod)
///   with data supplied by SpatialRepository.
///   The engine itself is stateless and pure.
/// ============================================================
library;

import 'dart:math' as math;

import 'package:famhub_app/core/spatial/domain/spatial_asset.dart';
import 'package:famhub_app/core/spatial/domain/spatial_boundary.dart';
import 'package:famhub_app/core/spatial/domain/spatial_capture_session.dart';
import 'package:famhub_app/core/spatial/domain/spatial_capture_point.dart';
import 'package:famhub_app/core/spatial/domain/spatial_overlap.dart';

/// ============================================================
/// SPATIAL ENGINE
/// ============================================================
///
/// Pure evaluation engine for spatial runtime logic.
/// All spatial computations flow through this engine.
///
/// The engine is stateless and immutable — pass data in, get
/// results out. State management belongs in providers.
/// ============================================================
class SpatialEngine {
  /// Currently selected spatial asset
  final SpatialAsset? currentAsset;

  /// Currently selected boundary
  final SpatialBoundary? selectedBoundary;

  /// Currently selected capture session
  final CaptureSession? selectedSession;

  /// Current capture points (for the selected session)
  final List<CapturePoint> capturePoints;

  /// Known overlaps for the current asset
  final List<SpatialOverlap> overlaps;

  /// All assets for the current context
  final List<SpatialAsset> allAssets;

  const SpatialEngine({
    this.currentAsset,
    this.selectedBoundary,
    this.selectedSession,
    this.capturePoints = const [],
    this.overlaps = const [],
    this.allAssets = const [],
  });

  // ============================================================
  // DERIVED STATE
  // ============================================================

  /// Whether a spatial asset is currently selected
  bool get hasSelectedAsset => currentAsset != null;

  /// The current asset's ID (or empty string)
  String get currentAssetId => currentAsset?.id ?? '';

  /// The current asset's type
  String? get currentAssetType => currentAsset?.assetType;

  /// The current asset's name
  String? get currentAssetName => currentAsset?.name;

  /// The current asset's parent ID
  String? get currentParentAssetId => currentAsset?.parentAssetId;

  /// The current asset's area from backend
  double? get currentAreaHa => currentAsset?.areaHa;

  // ============================================================
  // BOUNDARY STATE
  // ============================================================

  /// Whether the current asset has a boundary
  bool get hasBoundary => selectedBoundary != null;

  /// The boundary ID for the current asset
  String? get boundaryId => selectedBoundary?.id;

  /// The boundary geometry
  Map<String, dynamic>? get boundaryGeometry =>
      selectedBoundary?.geometry;

  /// The boundary accuracy level
  String? get boundaryAccuracyLevel =>
      selectedBoundary?.accuracyLevel;

  // ============================================================
  // CAPTURE STATE
  // ============================================================

  /// Whether a capture session is active
  bool get hasCapture => selectedSession != null;

  /// Whether the capture session is active (in progress)
  bool get isCaptureActive =>
      selectedSession != null && selectedSession!.isActive;

  /// Whether the capture is complete
  bool get isCaptureComplete =>
      selectedSession != null && selectedSession!.isCompleted;

  /// Whether the capture was cancelled
  bool get isCaptureCancelled =>
      selectedSession != null && selectedSession!.isCancelled;

  /// Number of capture points recorded
  int get capturePointCount => capturePoints.length;

  /// The session ID (if any)
  String? get captureSessionId => selectedSession?.id;

  /// The capture mode
  String? get captureMode => selectedSession?.mode;

  // ============================================================
  // OVERLAP STATE
  // ============================================================

  /// Whether any overlaps exist for the current asset
  bool get hasOverlap => overlaps.isNotEmpty;

  /// Number of overlaps
  int get overlapCount => overlaps.length;

  /// Overlaps where the current asset is assetA
  List<SpatialOverlap> get overlapsAsA =>
      overlaps.where((o) => o.assetA == currentAssetId).toList();

  /// Overlaps where the current asset is assetB
  List<SpatialOverlap> get overlapsAsB =>
      overlaps.where((o) => o.assetB == currentAssetId).toList();

  // ============================================================
  // AREA CALCULATION
  // ============================================================

  /// Calculate the area of the selected boundary in hectares.
  ///
  /// Uses the Shoelace formula on the boundary's geometry.
  /// Returns null if no boundary or unsupported geometry type.
  ///
  /// This is a client-side approximation. The backend PostGIS
  /// calculation (area_ha on the asset) is the source of truth.
  double? calculateArea() {
    if (selectedBoundary == null) return null;
    return _calculateGeoJsonArea(selectedBoundary!.geometry);
  }

  /// Calculate the perimeter of the selected boundary in meters.
  ///
  /// Returns null if no boundary or unsupported geometry type.
  double? calculatePerimeter() {
    if (selectedBoundary == null) return null;
    return _calculateGeoJsonPerimeter(selectedBoundary!.geometry);
  }

  // ============================================================
  // CHILD ASSET HELPERS
  // ============================================================

  /// Get direct children of the current asset.
  List<SpatialAsset> get childAssets {
    if (currentAsset == null) return [];
    return allAssets
        .where((a) => a.parentAssetId == currentAsset!.id)
        .toList();
  }

  /// Get the parent asset of the current asset.
  SpatialAsset? get parentAsset {
    if (currentAsset?.parentAssetId == null) return null;
    try {
      return allAssets.firstWhere(
        (a) => a.id == currentAsset!.parentAssetId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get siblings of the current asset (same parent).
  List<SpatialAsset> get siblingAssets {
    if (currentAsset?.parentAssetId == null) return [];
    return allAssets
        .where((a) =>
            a.parentAssetId == currentAsset!.parentAssetId &&
            a.id != currentAsset!.id)
        .toList();
  }

  /// Get the hierarchy from root to current asset.
  List<SpatialAsset> get assetHierarchy {
    final hierarchy = <SpatialAsset>[];
    if (currentAsset == null) return hierarchy;

    var current = currentAsset;
    hierarchy.insert(0, current!);

    // Walk up the parent chain
    while (current!.parentAssetId != null) {
      try {
        current = allAssets.firstWhere(
          (a) => a.id == current!.parentAssetId,
        );
        hierarchy.insert(0, current);
      } catch (_) {
        break;
      }
    }

    return hierarchy;
  }

  // ============================================================
  // PRIVATE: GEOJSON CALCULATIONS
  // ============================================================

  /// Calculate area of a GeoJSON geometry in hectares.
  ///
  /// Uses a simplified planar approximation.
  /// For production, use the backend PostGIS ST_Area result.
  double? _calculateGeoJsonArea(Map<String, dynamic> geometry) {
    try {
      final type = geometry['type'] as String?;
      if (type == null) return null;

      switch (type) {
        case 'Polygon':
          final coordinates = geometry['coordinates'] as List<dynamic>?;
          if (coordinates == null || coordinates.isEmpty) return null;
          final ring =
              (coordinates.first as List<dynamic>).cast<List<dynamic>>();
          final areaSqM = _planarPolygonArea(ring);
          return areaSqM / 10000.0; // Convert sq m to hectares

        case 'MultiPolygon':
          final coordinates = geometry['coordinates'] as List<dynamic>?;
          if (coordinates == null || coordinates.isEmpty) return null;
          double totalAreaSqM = 0;
          for (final polygon in coordinates) {
            final ring =
                (polygon as List<dynamic>).first as List<dynamic>;
            totalAreaSqM += _planarPolygonArea(
              ring.cast<List<dynamic>>(),
            );
          }
          return totalAreaSqM / 10000.0;

        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Calculate perimeter of a GeoJSON geometry in meters.
  double? _calculateGeoJsonPerimeter(Map<String, dynamic> geometry) {
    try {
      final type = geometry['type'] as String?;
      if (type == null) return null;

      switch (type) {
        case 'Polygon':
          final coordinates = geometry['coordinates'] as List<dynamic>?;
          if (coordinates == null || coordinates.isEmpty) return null;
          final ring =
              (coordinates.first as List<dynamic>).cast<List<dynamic>>();
          return _planarPolygonPerimeter(ring);

        case 'MultiPolygon':
          final coordinates = geometry['coordinates'] as List<dynamic>?;
          if (coordinates == null || coordinates.isEmpty) return null;
          double totalPerimeter = 0;
          for (final polygon in coordinates) {
            final ring =
                (polygon as List<dynamic>).first as List<dynamic>;
            totalPerimeter += _planarPolygonPerimeter(
              ring.cast<List<dynamic>>(),
            );
          }
          return totalPerimeter;

        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// Planar polygon area calculation (Shoelace formula).
  ///
  /// Coordinates are [longitude, latitude] pairs.
  /// This is an approximation — accurate only for small areas.
  double _planarPolygonArea(List<List<dynamic>> ring) {
    if (ring.length < 3) return 0;

    double area = 0;
    final n = ring.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      final xi = ring[i][0] as num;
      final yi = ring[i][1] as num;
      final xj = ring[j][0] as num;
      final yj = ring[j][1] as num;
      area += xi * yj - xj * yi;
    }
    area = area.abs() / 2.0;

    // Convert from square degrees to square meters (approximate)
    // At the equator: 1 deg ≈ 111,320 meters
    // This is a rough approximation; use backend for accuracy.
    const metersPerDegree = 111320.0;
    return area * metersPerDegree * metersPerDegree;
  }

  /// Planar polygon perimeter calculation.
  double _planarPolygonPerimeter(List<List<dynamic>> ring) {
    if (ring.length < 2) return 0;

    double perimeter = 0;
    final n = ring.length;
    for (int i = 0; i < n - 1; i++) {
      perimeter += _haversineDistance(
        (ring[i][0] as num).toDouble(),
        (ring[i][1] as num).toDouble(),
        (ring[i + 1][0] as num).toDouble(),
        (ring[i + 1][1] as num).toDouble(),
      );
    }
    // Close the ring
    perimeter += _haversineDistance(
      (ring.last[0] as num).toDouble(),
      (ring.last[1] as num).toDouble(),
      (ring.first[0] as num).toDouble(),
      (ring.first[1] as num).toDouble(),
    );

    return perimeter;
  }

  /// Haversine distance between two lat/lng points in meters.
  double _haversineDistance(
    double lng1,
    double lat1,
    double lng2,
    double lat2,
  ) {
    const earthRadius = 6371000.0; // meters

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
