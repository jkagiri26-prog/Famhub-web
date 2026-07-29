/// ============================================================
/// CROPS PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// 🏗️ OFFICIAL HIERARCHY:
///   Farm / Entity → Field / Block → **Crop** or Livestock → Activity → Report
///
/// ✅ PATTERN: repository → provider → controller → state → widgets
///
/// Provides crop list and management operations for a given farm.
/// Supports filtering by field/block in the hierarchy.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

/// Crop list state
class CropListState {
  final List<CropEntity> crops;
  final bool isLoading;
  final String? errorMessage;
  final String? searchQuery;

  /// The fieldId used for filtering (null = all fields for this farm)
  final String? fieldId;

  const CropListState({
    required this.crops,
    required this.isLoading,
    this.errorMessage,
    this.searchQuery,
    this.fieldId,
  });

  factory CropListState.initial() => const CropListState(
        crops: [],
        isLoading: true,
      );

  List<CropEntity> get filteredCrops {
    if (searchQuery == null || searchQuery!.isEmpty) return crops;

    final query = searchQuery!.toLowerCase();

    return crops.where((c) {
      return c.cropName.toLowerCase().contains(query) ||
          (c.variety?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  CropListState copyWith({
    List<CropEntity>? crops,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    String? fieldId,
  }) {
    return CropListState(
      crops: crops ?? this.crops,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      searchQuery: searchQuery ?? this.searchQuery,
      fieldId: fieldId ?? this.fieldId,
    );
  }
}

/// ============================================================
/// CROPS NOTIFIER (RIVERPOD 3 - NOTIFIER API)
/// ============================================================
class CropsNotifier extends Notifier<CropListState> {
  FarmRepository get _repository =>
      ref.read(farmRepositoryProvider);

  @override
  CropListState build() {
    return CropListState.initial();
  }

  Future<void> loadCrops({String? farmId, String? fieldId}) async {
    final effectiveFarmId = farmId ?? ref.read(farmContextProvider).farmId;
    if (effectiveFarmId == null) return;

    final effectiveFieldId = fieldId ?? ref.read(hierarchyProvider).fieldId;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final List<CropEntity> crops;
      if (effectiveFieldId != null) {
        crops = await _repository.getCropsByField(
          farmId: effectiveFarmId,
          fieldId: effectiveFieldId,
        );
      } else {
        crops = await _repository.getCrops(farmId: effectiveFarmId);
      }
      state = state.copyWith(
        crops: crops,
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

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Select a crop in the hierarchy and load its context
  Future<void> selectCropAndLoad(CropEntity crop) async {
    ref.read(hierarchyProvider.notifier).selectCrop(crop);
  }

  /// Clear crop selection back to field level
  void clearSelection() {
    ref.read(hierarchyProvider.notifier).clearToField();
  }
}

/// ============================================================
/// PROVIDER (NOTIFIER)
/// ============================================================
final cropsProvider =
    NotifierProvider<CropsNotifier, CropListState>(
  CropsNotifier.new,
);

/// Auto-loading crop provider based on farm context
final autoCropsProvider =
    Provider.family<AsyncValue<List<CropEntity>>, String?>(
  (ref, farmId) {
    final cropsState = ref.watch(cropsProvider);
    return AsyncValue.data(cropsState.filteredCrops);
  },
);

/// Crops filtered by the currently selected field in hierarchy
final cropsByFieldProvider = FutureProvider<List<CropEntity>>((ref) async {
  final farmId = ref.watch(farmContextProvider).farmId;
  final fieldId = ref.watch(hierarchyProvider).fieldId;
  if (farmId == null) return [];
  if (fieldId == null) return [];
  final repository = ref.read(farmRepositoryProvider);
  return repository.getCropsByField(farmId: farmId, fieldId: fieldId);
});

