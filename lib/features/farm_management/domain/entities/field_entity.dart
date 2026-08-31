/// ============================================================
/// FIELD ENTITY
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents a field or plot within a farm.
///
/// ✅ BACKEND CONTRACT (authoritative — farm_management.fields):
///   - id (uuid)
///   - farm_id (uuid)
///   - name (text NOT NULL)      ↔ app: fieldName
///   - description (text)        ↔ app: notes
///   - size (numeric)            ↔ app: acreage
///   - field_type (text)         ↔ app: type
///   - soil_type (text)          ↔ app: soilType
///   - is_active (boolean)       ↔ app: isActive
///   - unit_id (uuid)            ↔ app: unitId
///   - created_at (timestamptz)
///
/// 🚫 NOT PERSISTED (UI-context only — no backend column):
///   - currentCrop (no current_crop column)
///   - status (no status column; derived from is_active)
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class FieldEntity {
  final String id;
  final String farmId;
  final String fieldName; // backend: name
  final double? acreage; // backend: size
  final String? soilType; // backend: soil_type
  final String? currentCrop; // UI-only, NOT persisted
  final String? type; // backend: field_type
  final String? notes; // backend: description
  final bool isActive; // backend: is_active
  final String? unitId; // backend: unit_id
  final DateTime createdAt;

  const FieldEntity({
    required this.id,
    required this.farmId,
    required this.fieldName,
    this.acreage,
    this.soilType,
    this.currentCrop,
    this.type,
    this.notes,
    this.isActive = true,
    this.unitId,
    required this.createdAt,
  });

  /// Active state derived from the backend `is_active` column
  /// (the backend has no `status` column).
  String get status => isActive ? 'active' : 'inactive';

  /// Status label for display
  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      default:
        return status;
    }
  }

  /// Utilization percentage (placeholder — currentCrop is UI-only and not
  /// persisted; always false when loaded from the backend).
  bool get isCultivated => currentCrop != null && currentCrop!.isNotEmpty;

  FieldEntity copyWith({
    String? id,
    String? farmId,
    String? fieldName,
    double? acreage,
    String? soilType,
    String? currentCrop,
    String? type,
    String? notes,
    bool? isActive,
    String? unitId,
    DateTime? createdAt,
  }) {
    return FieldEntity(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      fieldName: fieldName ?? this.fieldName,
      acreage: acreage ?? this.acreage,
      soilType: soilType ?? this.soilType,
      currentCrop: currentCrop ?? this.currentCrop,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      unitId: unitId ?? this.unitId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

