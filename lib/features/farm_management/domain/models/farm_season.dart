/// ============================================================
/// FARM SEASON MODEL (Domain Layer)
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents a farming season or production cycle.
/// Seasons allow farmers to:
///   - Group activities, production, and reports by season
///   - Archive completed seasons while preserving historical data
///   - Start fresh each season with the same farm/field structure
///   - Compare performance across seasons
///
/// Example:
///   Green Valley Farm
///   ├── Season: 2025 Short Rains
///   ├── Season: 2025/2026 Long Rains
///   └── Season: 2026 Long Rains (Current)
/// ============================================================
library;

/// Status of a farming season
enum FarmSeasonStatus {
  /// Season is planned but not yet active
  planned,

  /// Season is currently active
  active,

  /// Season has been completed and archived
  archived,

  /// Season data has been cleaned up
  closed;

  String get label {
    switch (this) {
      case FarmSeasonStatus.planned:
        return 'Planned';
      case FarmSeasonStatus.active:
        return 'Active';
      case FarmSeasonStatus.archived:
        return 'Archived';
      case FarmSeasonStatus.closed:
        return 'Closed';
    }
  }
}

/// A farming season or production cycle
class FarmSeason {
  /// Unique identifier
  final String id;

  /// The farm this season belongs to
  final String farmId;

  /// Season label (e.g., "2025 Long Rains", "2025/2026 Season")
  final String name;

  /// Optional description
  final String? description;

  /// When this season started
  final DateTime startDate;

  /// When this season is expected to end
  final DateTime? expectedEndDate;

  /// When this season actually ended (null if still active)
  final DateTime? endDate;

  /// Current status
  final FarmSeasonStatus status;

  /// Whether this is the currently active season
  final bool isCurrent;

  const FarmSeason({
    required this.id,
    required this.farmId,
    required this.name,
    this.description,
    required this.startDate,
    this.expectedEndDate,
    this.endDate,
    this.status = FarmSeasonStatus.active,
    this.isCurrent = false,
  });

  FarmSeason copyWith({
    String? id,
    String? farmId,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? expectedEndDate,
    DateTime? endDate,
    FarmSeasonStatus? status,
    bool? isCurrent,
  }) {
    return FarmSeason(
      id: id ?? this.id,
      farmId: farmId ?? this.farmId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      expectedEndDate: expectedEndDate ?? this.expectedEndDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }

  /// Duration in days
  int? get durationDays {
    if (endDate == null) return null;
    return endDate!.difference(startDate).inDays;
  }

  /// Formatted range for display
  String get dateRangeDisplay {
    final start = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}';
    if (endDate == null) {
      return '$start - Present';
    }
    final end = '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}';
    return '$start to $end';
  }
}