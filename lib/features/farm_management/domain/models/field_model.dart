/// ============================================================
/// FIELD MODEL (DOMAIN ENTITY)
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents a field or plot within a farm.
///
/// Schema source (Supabase / Postgres):
///   farm_management.fields:
///     - id (uuid)
///     - farm_id (uuid)
///     - field_name (text)
///     - acreage (numeric, nullable, hectares)
///     - soil_type (text, nullable)
///     - current_crop (text, nullable)
///     - status (text): active, fallow, resting, leased
///     - notes (text, nullable)
///     - created_at (timestamptz)
/// ============================================================

class FieldModel {
  final String id;
  final String farmId;
  final String fieldName;
  final double? acreage;
  final String? soilType;
  final String? currentCrop;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const FieldModel({
    required this.id,
    required this.farmId,
    required this.fieldName,
    this.acreage,
    this.soilType,
    this.currentCrop,
    this.status = 'active',
    this.notes,
    required this.createdAt,
  });

  /// Status label for display
  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'fallow':
        return 'Fallow';
      case 'resting':
        return 'Resting';
      case 'leased':
        return 'Leased';
      default:
        return status;
    }
  }

  /// Utilization percentage (placeholder — no current_crop means fallow)
  bool get isCultivated => currentCrop != null && currentCrop!.isNotEmpty;

  FieldModel copyWith({
    String? id,
    String? farmId,
    String? fieldName,
    double? acreage,
    String? soilType,
    String? currentCrop,
    String? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return FieldModel(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      fieldName: fieldName ?? this.fieldName,
      acreage: acreage ?? this.acreage,
      soilType: soilType ?? this.soilType,
      currentCrop: currentCrop ?? this.currentCrop,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
