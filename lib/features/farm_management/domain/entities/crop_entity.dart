/// ============================================================
/// CROP ENTITY
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents a crop INSTANCE on a farm.
///
/// Schema source (Supabase / Postgres):
///   farm_management.assets (asset_type = 'crop'):
///     - id (uuid)  ← the crop asset id
///     - farm_id (uuid)
///     - field_id (uuid, nullable)
///     - variant_id (uuid → core.item_variants)
///     - quantity (numeric, nullable)
///     - unit_id (uuid, nullable)
///     - status (text)
///     - metadata (jsonb: variety, planting_date, notes, ...)
///     - created_at (timestamptz)
///
/// There is no separate `farm_management.crops` table; the crop kind is the
/// linked core.item_variants row (e.g. "Maize variant H614").

import 'package:famhub_app/features/farm_management/domain/enums/crop_status.dart';

class CropEntity {
  final String id;
  final String farmId;
  final String? fieldId;
  final String? variantId;
  final String cropName;
  final String? variety;
  final DateTime plantingDate;
  final DateTime? expectedHarvestDate;
  final double? areaPlanted;
  final double? quantityPlanted;
  final String? unit;
  final CropStatus status;
  final String? notes;
  final DateTime createdAt;

  const CropEntity({
    required this.id,
    required this.farmId,
    this.fieldId,
    this.variantId,
    required this.cropName,
    this.variety,
    required this.plantingDate,
    this.expectedHarvestDate,
    this.areaPlanted,
    this.quantityPlanted,
    this.unit,
    this.status = CropStatus.planted,
    this.notes,
    required this.createdAt,
  });

  /// Human-readable status label
  String get statusLabel {
    switch (status) {
      case CropStatus.planted:
        return 'Planted';
      case CropStatus.growing:
        return 'Growing';
      case CropStatus.harvested:
        return 'Harvested';
      case CropStatus.failed:
        return 'Failed';
    }
  }

  /// Duration since planting
  Duration get daysSincePlanting =>
      DateTime.now().difference(plantingDate);

  /// Days until expected harvest (null if no date set)
  int? get daysUntilHarvest {
    if (expectedHarvestDate == null) return null;
    return DateTime.now().difference(expectedHarvestDate!).inDays.abs();
  }

  CropEntity copyWith({
    String? id,
    String? farmId,
    String? fieldId,
    String? variantId,
    String? cropName,
    String? variety,
    DateTime? plantingDate,
    DateTime? expectedHarvestDate,
    double? areaPlanted,
    double? quantityPlanted,
    String? unit,
    CropStatus? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return CropEntity(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      fieldId: fieldId ?? this.fieldId,
      variantId: variantId ?? this.variantId,
      cropName: cropName ?? this.cropName,
      variety: variety ?? this.variety,
      plantingDate: plantingDate ?? this.plantingDate,
      expectedHarvestDate: expectedHarvestDate ?? this.expectedHarvestDate,
      areaPlanted: areaPlanted ?? this.areaPlanted,
      quantityPlanted: quantityPlanted ?? this.quantityPlanted,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

