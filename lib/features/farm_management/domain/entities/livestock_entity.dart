/// ============================================================
/// LIVESTOCK ENTITY
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents a livestock animal or group within a farm.
///
/// Schema source (Supabase / Postgres):
///   farm_management.livestock:
///     - id (uuid)
///     - farm_id (uuid)
///     - species (text)
///     - breed (text, nullable)
///     - count (integer)
///     - date_of_birth (date, nullable)
///     - health_status (text, nullable)
///     - purpose (text, nullable): meat, dairy, breeding, etc.
///     - notes (text, nullable)
///     - created_at (timestamptz)
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

class LivestockEntity {
  final String id;
  final String farmId;
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

