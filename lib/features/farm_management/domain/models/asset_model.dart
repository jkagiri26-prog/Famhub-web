/// ============================================================
/// ASSET MODEL (DOMAIN ENTITY)
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents a farm asset (machinery, equipment, infrastructure).
///
/// Schema source (Supabase / Postgres):
///   farm_management.assets:
///     - id (uuid)
///     - farm_id (uuid)
///     - asset_name (text)
///     - asset_type (text): machinery, equipment, structure, vehicle, other
///     - manufacturer (text, nullable)
///     - model (text, nullable)
///     - year_purchased (integer, nullable)
///     - condition (text, nullable): excellent, good, fair, poor
///     - last_maintenance_date (date, nullable)
///     - notes (text, nullable)
///     - is_active (boolean)
///     - created_at (timestamptz)
/// ============================================================

class AssetModel {
  final String id;
  final String farmId;
  final String assetName;
  final String assetType;
  final String? manufacturer;
  final String? model;
  final int? yearPurchased;
  final String? condition;
  final DateTime? lastMaintenanceDate;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  const AssetModel({
    required this.id,
    required this.farmId,
    required this.assetName,
    required this.assetType,
    this.manufacturer,
    this.model,
    this.yearPurchased,
    this.condition,
    this.lastMaintenanceDate,
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  /// Type label for display
  String get typeLabel {
    switch (assetType) {
      case 'machinery':
        return 'Machinery';
      case 'equipment':
        return 'Equipment';
      case 'structure':
        return 'Structure';
      case 'vehicle':
        return 'Vehicle';
      default:
        return 'Other';
    }
  }

  /// Condition label with fallback
  String get conditionLabel => condition ?? 'Unknown';

  /// Days since last maintenance
  int? get daysSinceMaintenance {
    if (lastMaintenanceDate == null) return null;
    return DateTime.now().difference(lastMaintenanceDate!).inDays;
  }

  AssetModel copyWith({
    String? id,
    String? farmId,
    String? assetName,
    String? assetType,
    String? manufacturer,
    String? model,
    int? yearPurchased,
    String? condition,
    DateTime? lastMaintenanceDate,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AssetModel(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      assetName: assetName ?? this.assetName,
      assetType: assetType ?? this.assetType,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      yearPurchased: yearPurchased ?? this.yearPurchased,
      condition: condition ?? this.condition,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
