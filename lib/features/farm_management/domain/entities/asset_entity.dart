/// ============================================================
/// ASSET ENTITY
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents a farm asset (crop/livestock instance, machinery,
/// equipment, infrastructure).
///
/// ✅ BACKEND CONTRACT (authoritative — farm_management.assets):
///   - id (uuid)
///   - entity_id (uuid)            ↔ app: entityId
///   - farm_id (uuid)              ↔ app: farmId
///   - asset_type (text)           ↔ app: assetType ('crop'|'livestock'|…)
///   - variant_id (uuid NOT NULL)  ↔ app: variantId (core.item_variants)
///   - field_id (uuid)             ↔ app: fieldId
///   - status (text)               ↔ app: status
///   - quantity (numeric)          ↔ app: quantity
///   - unit_id (uuid)              ↔ app: unitId
///   - metadata (jsonb)            ↔ app: metadata
///   - acquired_at (timestamptz)   ↔ app: acquiredAt
///   - created_at (timestamptz)
///
/// 🚫 NOT PERSISTED (UI-context only — no backend column):
///   - assetName (resolved from core.item_variants / metadata.name)
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class AssetEntity {
  final String id;
  final String farmId;
  final String? entityId;

  /// Backend `asset_type` (e.g. crop, livestock, machinery, equipment).
  final String assetType;

  /// Backend `variant_id` → core.item_variants.id.
  final String? variantId;

  /// Backend `field_id` → farm_management.fields.id.
  final String? fieldId;

  /// Backend `status` (e.g. active, depleted, archived).
  final String status;

  /// Backend `quantity`.
  final double quantity;

  /// Backend `unit_id` → core.units.id.
  final String? unitId;

  /// Backend `metadata` jsonb.
  final Map<String, dynamic> metadata;

  /// Backend `acquired_at`.
  final DateTime? acquiredAt;

  /// Backend `created_at`.
  final DateTime createdAt;

  /// Resolved display label (from core.item_variants, falling back to
  /// metadata['name']). NOT a persisted column.
  final String assetName;

  const AssetEntity({
    required this.id,
    required this.farmId,
    this.entityId,
    required this.assetType,
    this.variantId,
    this.fieldId,
    this.status = 'active',
    this.quantity = 0,
    this.unitId,
    this.metadata = const {},
    this.acquiredAt,
    required this.createdAt,
    required this.assetName,
  });

  /// Active state derived from the backend `status` column.
  bool get isActive => status == 'active';

  /// Quantity value (backend `quantity`).
  double get quantityValue => quantity;

  /// Status label for display.
  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'depleted':
        return 'Depleted';
      case 'archived':
        return 'Archived';
      default:
        return status;
    }
  }

  /// Type label for display.
  String get typeLabel {
    switch (assetType.toLowerCase()) {
      case 'crop':
        return 'Crop';
      case 'livestock':
        return 'Livestock';
      case 'machinery':
        return 'Machinery';
      case 'equipment':
        return 'Equipment';
      case 'structure':
        return 'Structure';
      case 'vehicle':
        return 'Vehicle';
      case 'input':
        return 'Input';
      case 'feed':
        return 'Feed';
      default:
        return assetType.isEmpty
            ? 'Asset'
            : assetType[0].toUpperCase() + assetType.substring(1);
    }
  }

  AssetEntity copyWith({
    String? id,
    String? farmId,
    String? entityId,
    String? assetType,
    String? variantId,
    String? fieldId,
    String? status,
    double? quantity,
    String? unitId,
    Map<String, dynamic>? metadata,
    DateTime? acquiredAt,
    DateTime? createdAt,
    String? assetName,
  }) {
    return AssetEntity(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      entityId: entityId ?? this.entityId,
      assetType: assetType ?? this.assetType,
      variantId: variantId ?? this.variantId,
      fieldId: fieldId ?? this.fieldId,
      status: status ?? this.status,
      quantity: quantity ?? this.quantity,
      unitId: unitId ?? this.unitId,
      metadata: metadata ?? this.metadata,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      createdAt: createdAt ?? this.createdAt,
      assetName: assetName ?? this.assetName,
    );
  }
}
