/// ============================================================
/// LIVESTOCK PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// 🏗️ OFFICIAL HIERARCHY:
///   Farm / Entity → Field / Block → **Livestock** or Crop → Activity → Report
///
/// ✅ PATTERN: repository → provider → state → widgets
///
/// Provides livestock inventory and management operations.
/// Supports filtering by field/block in the hierarchy.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

/// Livestock list state
class LivestockListState {
  final List<LivestockEntity> livestock;
  final bool isLoading;
  final String? errorMessage;
  final String? speciesFilter;

  /// The fieldId used for filtering (null = all fields for this farm)
  final String? fieldId;

  const LivestockListState({
    required this.livestock,
    required this.isLoading,
    this.errorMessage,
    this.speciesFilter,
    this.fieldId,
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
    String? fieldId,
  }) {
    return LivestockListState(
      livestock: livestock ?? this.livestock,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      speciesFilter: speciesFilter ?? this.speciesFilter,
      fieldId: fieldId ?? this.fieldId,
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

  Future<void> loadLivestock({String? farmId, String? fieldId}) async {
    final effectiveFarmId = farmId ?? ref.read(farmContextProvider).farmId;
    if (effectiveFarmId == null) return;

    final effectiveFieldId = fieldId ?? ref.read(hierarchyProvider).fieldId;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final List<LivestockEntity> livestock;
      if (effectiveFieldId != null) {
        livestock = await _repository.getLivestockByField(
          farmId: effectiveFarmId,
          fieldId: effectiveFieldId,
        );
      } else {
        livestock = await _repository.getLivestock(farmId: effectiveFarmId);
      }
      state = state.copyWith(
        livestock: livestock,
        isLoading: false,
        fieldId: effectiveFieldId,
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

  /// Select a livestock record in the hierarchy
  Future<void> selectLivestockAndLoad(LivestockEntity animal) async {
    ref.read(hierarchyProvider.notifier).selectLivestock(animal);
  }
}

/// ============================================================
/// PROVIDER (NOTIFIER)
/// ============================================================
final livestockProvider =
    NotifierProvider<LivestockNotifier, LivestockListState>(
  LivestockNotifier.new,
);

/// Livestock filtered by the currently selected field in hierarchy
final livestockByFieldProvider = FutureProvider<List<LivestockEntity>>((ref) async {
  final farmId = ref.watch(farmContextProvider).farmId;
  final fieldId = ref.watch(hierarchyProvider).fieldId;
  if (farmId == null) return [];
  if (fieldId == null) return [];
  final repository = ref.read(farmRepositoryProvider);
  return repository.getLivestockByField(farmId: farmId, fieldId: fieldId);
});
