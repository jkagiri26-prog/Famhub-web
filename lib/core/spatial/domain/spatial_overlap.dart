/// ============================================================
/// SPATIAL OVERLAP — DOMAIN MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/domain/ = spatial domain models
///
/// Mirrors the backend `spatial.spatial_overlaps` table.
/// Represents an overlap between two spatial assets.
///
/// ✅ Responsibilities:
///   - Define the immutable spatial overlap model
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
/// SPATIAL OVERLAP
/// ============================================================
///
/// Immutable model representing a detected overlap between
/// two spatial assets. Computed by the backend PostGIS engine.
///
/// Backend table: `spatial.spatial_overlaps`
///
/// overlap_type values: 'boundary', 'buffer', 'zone'
/// ============================================================
class SpatialOverlap {
  /// Primary identifier (uuid)
  final String id;

  /// First asset in the overlap pair
  final String assetA;

  /// Second asset in the overlap pair
  final String assetB;

  /// Type of overlap: 'boundary', 'buffer', 'zone'
  final String overlapType;

  /// Overlap area in square meters
  final double? overlapAreaSqM;

  /// Overlap as a percentage (0-100)
  final double? overlapPercent;

  /// Created at timestamp (milliseconds since epoch)
  final int? createdAt;

  const SpatialOverlap({
    required this.id,
    required this.assetA,
    required this.assetB,
    this.overlapType = 'boundary',
    this.overlapAreaSqM,
    this.overlapPercent,
    this.createdAt,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  SpatialOverlap copyWith({
    String? id,
    String? assetA,
    String? assetB,
    String? overlapType,
    double? overlapAreaSqM,
    double? overlapPercent,
    int? createdAt,
  }) {
    return SpatialOverlap(
      id: id ?? this.id,
      assetA: assetA ?? this.assetA,
      assetB: assetB ?? this.assetB,
      overlapType: overlapType ?? this.overlapType,
      overlapAreaSqM: overlapAreaSqM ?? this.overlapAreaSqM,
      overlapPercent: overlapPercent ?? this.overlapPercent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// ============================================================
  /// SERIALIZATION
  /// ============================================================

  /// Serialize to a map
  Map<String, dynamic> toJson() => {
        'id': id,
        'asset_a': assetA,
        'asset_b': assetB,
        'overlap_type': overlapType,
        'overlap_area_sq_m': overlapAreaSqM,
        'overlap_percentage': overlapPercent,
        'created_at': createdAt,
      };

  /// Deserialize from a map
  factory SpatialOverlap.fromJson(Map<String, dynamic> json) =>
      SpatialOverlap(
        id: json['id'] as String,
        assetA: (json['asset_a'] ?? json['assetA']) as String,
        assetB: (json['asset_b'] ?? json['assetB']) as String,
        overlapType:
            (json['overlap_type'] ?? json['overlapType'] ?? 'boundary')
                as String,
        overlapAreaSqM:
            (json['overlap_area_sq_m'] ?? json['overlapAreaSqM'] as num?)
                ?.toDouble(),
        overlapPercent:
            (json['overlap_percentage'] ?? json['overlapPercent'] as num?)
                ?.toDouble(),
        createdAt: (json['created_at'] ?? json['createdAt']) as int?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpatialOverlap &&
          id == other.id &&
          runtimeType == other.runtimeType;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'SpatialOverlap($assetA ↔ $assetB, ${overlapPercent?.toStringAsFixed(1) ?? "?"}%)';
}
