/// ============================================================
/// LIVESTOCK ENTITY
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents a livestock INSTANCE (group) on a farm.
///
/// Schema source (Supabase / Postgres):
///   farm_management.assets (asset_type = 'livestock'):
///     - id (uuid)  ← the livestock asset id
///     - farm_id (uuid)
///     - field_id (uuid, nullable)
///     - variant_id (uuid → core.item_variants)
///     - quantity (numeric, nullable; head count)
///     - unit_id (uuid, nullable)
///     - status (text)
///     - metadata (jsonb: breed, notes, ...)
///     - created_at (timestamptz)
///
/// There is no separate `farm_management.livestock` table; the species is the
/// linked core.item_variants row (e.g. "Friesian").
class LivestockEntity {
  final String id;
  final String farmId;
  final String? fieldId;
  final String? variantId;
  final String species;
  final String? breed;
  final int count;
  final DateTime? dateOfBirth;
  final String? healthStatus;
  final String? purpose;
  final String? notes;
  final DateTime createdAt;

  const LivestockEntity({
    required this.id,
    required this.farmId,
    this.fieldId,
    this.variantId,
    required this.species,
    this.breed,
    required this.count,
    this.dateOfBirth,
    this.healthStatus,
    this.purpose,
    this.notes,
    required this.createdAt,
  });

  /// Human-readable purpose label
  String get purposeLabel => purpose ?? 'General';

  /// Health status with fallback
  String get healthLabel => healthStatus ?? 'Unknown';

  /// Age in months (if dateOfBirth is known)
  int? get ageInMonths {
    if (dateOfBirth == null) return null;
    final diff = DateTime.now().difference(dateOfBirth!);
    return (diff.inDays / 30.44).round();
  }

  LivestockEntity copyWith({
    String? id,
    String? farmId,
    String? fieldId,
    String? variantId,
    String? species,
    String? breed,
    int? count,
    DateTime? dateOfBirth,
    String? healthStatus,
    String? purpose,
    String? notes,
    DateTime? createdAt,
  }) {
    return LivestockEntity(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      fieldId: fieldId ?? this.fieldId,
      variantId: variantId ?? this.variantId,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      count: count ?? this.count,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      healthStatus: healthStatus ?? this.healthStatus,
      purpose: purpose ?? this.purpose,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

