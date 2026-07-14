/// ============================================================
/// SPATIAL BOUNDARY — DOMAIN MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/domain/ = spatial domain models
///
/// Mirrors the backend `spatial.spatial_boundaries` table.
/// Represents the geometry boundary of a spatial asset.
///
/// ✅ Responsibilities:
///   - Define the immutable spatial boundary model
///   - Mirror backend schema exactly
///   - Pure Dart — no Flutter imports
///
/// ❌ Does NOT:
///   - Import Flutter
///   - Contain business logic
///   - Contain UI
/// ============================================================
library;

/// ============================================================
/// SPATIAL BOUNDARY
/// ============================================================
///
/// Immutable model representing a boundary polygon for a spatial asset.
///
/// Backend table: `spatial.spatial_boundaries`
///
/// The `geometry` field contains GeoJSON geometry (Polygon or MultiPolygon).
/// The backend stores PostGIS geometry; the frontend receives it as GeoJSON.
///
/// accuracy_level values: 'gps', 'survey', 'satellite', 'drone', 'cadastral'
/// ============================================================
class SpatialBoundary {
  /// Primary identifier (uuid)
  final String id;

  /// Foreign key to the spatial asset
  final String assetId;

  /// GeoJSON geometry (Polygon or MultiPolygon) as a Map
  /// Backend stores PostGIS geometry, frontend receives GeoJSON
  final Map<String, dynamic> geometry;

  /// Accuracy level of the boundary
  final String accuracyLevel;

  /// Created at timestamp (milliseconds since epoch)
  final int? createdAt;

  const SpatialBoundary({
    required this.id,
    required this.assetId,
    required this.geometry,
    this.accuracyLevel = 'gps',
    this.createdAt,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  SpatialBoundary copyWith({
    String? id,
    String? assetId,
    Map<String, dynamic>? geometry,
    String? accuracyLevel,
    int? createdAt,
  }) {
    return SpatialBoundary(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      geometry: geometry ?? this.geometry,
      accuracyLevel: accuracyLevel ?? this.accuracyLevel,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// ============================================================
  /// SERIALIZATION
  /// ============================================================

  /// Serialize to a map
  Map<String, dynamic> toJson() => {
        'id': id,
        'asset_id': assetId,
        'geometry': geometry,
        'accuracy_level': accuracyLevel,
        'created_at': createdAt,
      };

  /// Deserialize from a map
  factory SpatialBoundary.fromJson(Map<String, dynamic> json) =>
      SpatialBoundary(
        id: json['id'] as String,
        assetId: (json['asset_id'] ?? json['assetId']) as String,
        geometry: (json['geometry'] ?? json['geometry'])
            as Map<String, dynamic>,
        accuracyLevel: (json['accuracy_level'] ?? json['accuracyLevel'])
                as String? ??
            'gps',
        createdAt: (json['created_at'] ?? json['createdAt']) as int?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpatialBoundary &&
          id == other.id &&
          runtimeType == other.runtimeType;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SpatialBoundary(asset: $assetId, accuracy: $accuracyLevel)';
}
