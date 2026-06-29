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
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';

/// Livestock list state
class LivestockListState {
  final List<LivestockEntity> livestock;
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


  List<LivestockEntity> get filteredLivestock {
    if (speciesFilter == null || speciesFilter!.isEmpty) return livestock;
    return livestock
        .where((l) =>
            l.species.toLowerCase() == speciesFilter!.toLowerCase())
        .toList();
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
    List<LivestockEntity>? livestock,
    bool? isLoading,
    String? errorMessage,
    String? speciesFilter,
  }) {
    return LivestockListState(
      livestock: livestock ?? this.livestock,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      speciesFilter: speciesFilter ?? this.speciesFilter,
    );
  }
}

/// ============================================================
/// LIVESTOCK NOTIFIER (RIVERPOD 3 - NOTIFIER API)
/// ============================================================
class LivestockNotifier extends Notifier<LivestockListState> {
  FarmRepository get _repository =>
      ref.read(farmRepositoryProvider);

  @override
  LivestockListState build() {
    return LivestockListState.initial();
  }

  Future<void> loadLivestock({String? farmId}) async {
    final effectiveFarmId = farmId ?? ref.read(farmContextProvider).farmId;
    if (effectiveFarmId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final livestock =
          await _repository.getLivestock(farmId: effectiveFarmId);

      state = state.copyWith(
        livestock: livestock,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setSpeciesFilter(String? species) {
    state = state.copyWith(speciesFilter: species);
  }
}

/// ============================================================
/// PROVIDER (NOTIFIER)
/// ============================================================
final livestockProvider =
    NotifierProvider<LivestockNotifier, LivestockListState>(
  LivestockNotifier.new,
);