/// ============================================================
/// LIVESTOCK PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// ✅ PATTERN: repository → provider → state → widgets
///
/// Provides livestock inventory and management operations.
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/livestock_model.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';

/// Livestock list state
class LivestockListState {
  final List<LivestockModel> livestock;
  final bool isLoading;
  final String? errorMessage;
  final String? speciesFilter;

  const LivestockListState({
    required this.livestock,
    required this.isLoading,
    this.errorMessage,
    this.speciesFilter,
  });

  factory LivestockListState.initial() => const LivestockListState(
        livestock: [],
        isLoading: true,
      );

  /// Filtered list by species
  List<LivestockModel> get filteredLivestock {
    if (speciesFilter == null || speciesFilter!.isEmpty) return livestock;
    return livestock.where((l) =>
      l.species.toLowerCase() == speciesFilter!.toLowerCase()
    ).toList();
  }

  /// Total animal count
  int get totalCount => livestock.fold(0, (sum, l) => sum + l.count);

  /// Unique species list
  List<String> get species => livestock
      .map((l) => l.species)
      .toSet()
      .toList()
    ..sort();

  LivestockListState copyWith({
    List<LivestockModel>? livestock,
    bool? isLoading,
    String? errorMessage,
    String? speciesFilter,
  }) {
    return LivestockListState(
      livestock: livestock ?? this.livestock,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      speciesFilter: speciesFilter,
    );
  }
}

/// Livestock notifier
class LivestockNotifier extends StateNotifier<LivestockListState> {
  final FarmRepository _repository;
  final String? _farmId;

  LivestockNotifier(this._repository, this._farmId)
      : super(LivestockListState.initial());

  Future<void> loadLivestock() async {
    if (_farmId == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final livestock = await _repository.getLivestock(farmId: _farmId!);
      state = state.copyWith(livestock: livestock, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setSpeciesFilter(String? species) {
    state = state.copyWith(speciesFilter: species);
  }
}

/// Provider for livestock list
final livestockProvider = StateNotifierProvider.family<LivestockNotifier, LivestockListState, String?>(
  (ref, farmId) {
    final repository = ref.read(farmRepositoryProvider);
    return LivestockNotifier(repository, farmId);
  },
);
