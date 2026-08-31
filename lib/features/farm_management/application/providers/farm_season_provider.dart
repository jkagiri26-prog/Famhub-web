/// ============================================================
/// FARM SEASON PROVIDER
/// ============================================================
///
/// 🧠 APPLICATION LAYER
///
/// Manages farming seasons for the selected farm.
/// Seasons allow farmers to:
///   - Group activities, production, and reports by season
///   - Archive completed seasons while preserving farm/field structure
///   - Start fresh each season
///   - Compare performance across seasons
///
/// The current season is auto-created when the farm is created.
/// A new season can be started when the current one is complete.
///
/// ⚠️ LIMITATION (backend dependency): Season UI and local season state
/// are available, but lifecycle calculations are NOT yet database-isolated
/// by season. The backend tables (activities, production_records,
/// financial_records) have no `season_id` column, so historical
/// non-season records are not filtered by the current season.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/farm_season.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';

/// State for farm seasons
class FarmSeasonState {
  /// All seasons for the current farm
  final List<FarmSeason> seasons;

  /// The currently active season
  final FarmSeason? currentSeason;

  /// Whether seasons are loading
  final bool isLoading;

  const FarmSeasonState({
    required this.seasons,
    this.currentSeason,
    this.isLoading = false,
  });

  factory FarmSeasonState.initial() => const FarmSeasonState(
        seasons: [],
        isLoading: true,
      );

  FarmSeasonState copyWith({
    List<FarmSeason>? seasons,
    FarmSeason? currentSeason,
    bool? isLoading,
    bool clearCurrent = false,
  }) {
    return FarmSeasonState(
      seasons: seasons ?? this.seasons,
      currentSeason: clearCurrent ? null : (currentSeason ?? this.currentSeason),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SEASON NOTIFIER
// ════════════════════════════════════════════════════════════════

class FarmSeasonNotifier extends Notifier<FarmSeasonState> {
  @override
  FarmSeasonState build() {
    // Auto-generate a current season when the farm context changes
    ref.listen(farmContextProvider, (previous, next) {
      if (next.farmId != null && state.seasons.isEmpty) {
        _initializeCurrentSeason(next.farmId!);
      }
    });

    return FarmSeasonState.initial();
  }

  /// Initialize the current season for a farm.
  /// This is called automatically when the farm is selected.
  void _initializeCurrentSeason(String farmId) {
    final now = DateTime.now();
    final seasonName = _generateSeasonName(now);

    final currentSeason = FarmSeason(
      id: '$farmId-${now.year}-${now.month}',
      farmId: farmId,
      name: seasonName,
      startDate: now,
      status: FarmSeasonStatus.active,
      isCurrent: true,
    );

    state = FarmSeasonState(
      seasons: [currentSeason],
      currentSeason: currentSeason,
      isLoading: false,
    );
  }

  /// Generate a season name based on the date.
  /// Examples: "2025 Long Rains", "2025/2026 Season"
  String _generateSeasonName(DateTime date) {
    final year = date.year;
    final month = date.month;

    // Southern/Eastern Africa rainfall patterns
    if (month >= 3 && month <= 5) {
      return '$year Long Rains';
    } else if (month >= 10 && month <= 12) {
      return '$year Short Rains';
    } else if (month >= 6 && month <= 9) {
      return '$year Cool Dry';
    } else {
      return '$year Season';
    }
  }

  /// Start a new season and archive the current one.
  Future<void> startNewSeason({String? customName}) async {
    final currentSeason = state.currentSeason;
    final now = DateTime.now();

    final archivedSeasons = <FarmSeason>[];
    if (currentSeason != null) {
      // Archive the current season
      archivedSeasons.add(currentSeason.copyWith(
        endDate: now,
        status: FarmSeasonStatus.archived,
        isCurrent: false,
      ));
    }

    // Create the new season
    final newSeason = FarmSeason(
      id: '${currentSeason?.farmId ?? 'farm'}-${now.year}-${now.month}',
      farmId: currentSeason?.farmId ?? '',
      name: customName ?? _generateSeasonName(now),
      startDate: now,
      status: FarmSeasonStatus.active,
      isCurrent: true,
    );

    // Preserve existing archived seasons, add the newly archived one
    final allSeasons = [
      ...archivedSeasons,
      ...state.seasons.where((s) => s.status == FarmSeasonStatus.archived),
      newSeason,
    ];

    state = FarmSeasonState(
      seasons: allSeasons,
      currentSeason: newSeason,
      isLoading: false,
    );
  }

  /// Get the season display string for the current farm
  String? get currentSeasonDisplay => state.currentSeason?.name;
}

// ════════════════════════════════════════════════════════════════
// PROVIDER
// ════════════════════════════════════════════════════════════════

final farmSeasonProvider =
    NotifierProvider<FarmSeasonNotifier, FarmSeasonState>(
  FarmSeasonNotifier.new,
);