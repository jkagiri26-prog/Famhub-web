/// ============================================================
/// SPATIAL ASSET — DOMAIN MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/domain/ = spatial domain models
///
/// Mirrors the backend `spatial.spatial_assets` table.
/// Represents a farm, field, block, or any spatial unit.
///
/// ✅ Responsibilities:
///   - Define the immutable spatial asset model
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
/// SPATIAL ASSET
/// ============================================================
///
/// Immutable model representing a spatial asset from the backend.
///
/// Backend table: `spatial.spatial_assets`
/// Schema: docs/Backend schemas/spatial schema.md
///
/// asset_type values: 'farm', 'field', 'block', 'carbon_zone',
///   'forest', 'woodlot', 'water_body', 'wetland', 'pasture',
///   'orchard', 'greenhouse', 'other'
///
/// Examples:
///   - Manor Farm (assetType: 'farm')
///   - Field 3A (assetType: 'field')
///   - Block 5 (assetType: 'block')
///   - Carbon Zone Alpha (assetType: 'carbon_zone')
/// ============================================================
class SpatialAsset {
  /// Primary identifier (uuid)
  final String id;

  /// Foreign key to the entity (farm, organization, etc.)
  final String entityId;

  /// Type of asset — constrained by backend CHECK constraint
  final String assetType;

  /// Human-readable name
  final String name;

  /// Area in hectares (from backend spatial calculation)
  final double? areaHa;

  /// Parent asset ID for hierarchical structure (self-referencing FK)
  final String? parentAssetId;

  /// Arbitrary metadata (jsonb)
  final Map<String, dynamic>? metadata;

  /// Created at timestamp (milliseconds since epoch)
  final int? createdAt;

  /// Updated at timestamp (milliseconds since epoch)
  final int? updatedAt;

  const SpatialAsset({
    required this.id,
    required this.entityId,
    required this.assetType,
    required this.name,
    this.areaHa,
    this.parentAssetId,
    this.metadata,
    this.createdAt,
    this.updatedAt,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  SpatialAsset copyWith({
    String? id,
    String? entityId,
    String? assetType,
    String? name,
    double? areaHa,
    String? parentAssetId,
    Map<String, dynamic>? metadata,
    int? createdAt,
    int? updatedAt,
  }) {
    return SpatialAsset(
      id: id ?? this.id,
      entityId: entityId ?? this.entityId,
      assetType: assetType ?? this.assetType,
      name: name ?? this.name,
      areaHa: areaHa ?? this.areaHa,
      parentAssetId: parentAssetId ?? this.parentAssetId,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// ============================================================
  /// SERIALIZATION
  /// ============================================================

  /// Serialize to a map (for JSON/API transport)
  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_id': entityId,
        'asset_type': assetType,
        'name': name,
        'area_ha': areaHa,
        'parent_asset_id': parentAssetId,
        'metadata': metadata,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  /// Deserialize from a map (from JSON/API response)
  factory SpatialAsset.fromJson(Map<String, dynamic> json) => SpatialAsset(
        id: json['id'] as String,
        entityId: (json['entity_id'] ?? json['entityId']) as String,
        assetType: (json['asset_type'] ?? json['assetType']) as String,
        name: json['name'] as String,
        areaHa: (json['area_ha'] ?? json['areaHa'] as num?)?.toDouble(),
        parentAssetId: (json['parent_asset_id'] ?? json['parentAssetId']) as String?,
        metadata: (json['metadata'] ?? json['metadata']) as Map<String, dynamic>?,
        createdAt: (json['created_at'] ?? json['createdAt']) as int?,
        updatedAt: (json['updated_at'] ?? json['updatedAt']) as int?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpatialAsset && id == other.id &&
          runtimeType == other.runtimeType;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SpatialAsset($assetType: $name [$id])';
}
