/// ============================================================
/// CROP MODEL (DOMAIN ENTITY)
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents a crop record within a farm.
///
/// Schema source (Supabase / Postgres):
///   farm_management.crops:
///     - id (uuid)
///     - farm_id (uuid)
///     - field_id (uuid, nullable)
///     - crop_name (text)
///     - variety (text, nullable)
///     - planting_date (date)
///     - expected_harvest_date (date, nullable)
///     - area_planted (numeric, nullable, hectares)
///     - quantity_planted (numeric, nullable)
///     - unit (text, nullable)
///     - status (crop_status enum): planted, growing, harvested, failed
///     - notes (text, nullable)
///     - created_at (timestamptz)
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

enum CropStatus { planted, growing, harvested, failed }

class CropModel {
  final String id;
  final String farmId;
  final String? fieldId;
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

  const CropModel({
    required this.id,
    required this.farmId,
    this.fieldId,
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

  CropModel copyWith({
    String? id,
    String? farmId,
    String? fieldId,
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
    return CropModel(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      fieldId: fieldId ?? this.fieldId,
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
