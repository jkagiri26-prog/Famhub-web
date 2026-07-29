/// ============================================================
/// SEASON ENTITY
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents a farming season within a farm.
/// A farm can have multiple seasons over time.
///
/// When a season ends:
///   - Activities, production records, and reports are ARCHIVED
///     (not deleted — preserved for historical analysis)
///   - The farm and field structure REMAINS
///   - The next season starts clean regarding crops and livestock
///   - Users can view historical seasons as read-only snapshots
///
/// Season naming convention:
///   "{Year} {Season Name}" e.g. "2026 Long Rains"
/// ============================================================
library;

/// Status of a season within a farm
enum SeasonStatus {
  /// The season is the current active season
  active,

  /// The season has ended and is preserved for history
  archived,
}

/// Represents a farming season
class SeasonEntity {
  final String id;
  final String farmId;

  /// Human-readable name, e.g. "2026 Long Rains"
  final String name;

  /// Optional description of the season
  final String? description;

  /// When the season started
  final DateTime startDate;

  /// When the season ended (null if still active)
  final DateTime? endDate;

  /// Current status
  final SeasonStatus status;

  /// When this entity was created
  final DateTime createdAt;

  const SeasonEntity({
    required this.id,
    required this.farmId,
    required this.name,
    this.description,
    required this.startDate,
    this.endDate,
    this.status = SeasonStatus.active,
    required this.createdAt,
  });

  /// Whether the season is currently active
  bool get isActive => status == SeasonStatus.active;

  /// Whether the season has been archived
  bool get isArchived => status == SeasonStatus.archived;

  /// Duration of the season in days (null if still active)
  int? get durationDays {
    if (endDate == null) return null;
    return endDate!.difference(startDate).inDays;
  }

  SeasonEntity copyWith({
    String? id,
    String? farmId,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    SeasonStatus? status,
    DateTime? createdAt,
  }) {
    return SeasonEntity(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Generate a default season name based on date
  static String defaultNameForDate(DateTime date) {
    final year = date.year;
    final month = date.month;
    // Simple season naming: Long Rains (Mar-Jun), Short Rains (Oct-Dec), Dry (Jul-Sep, Jan-Feb)
    if (month >= 3 && month <= 6) return '$year Long Rains';
    if (month >= 10 && month <= 12) return '$year Short Rains';
    return '$year Dry Season';
  }
}