/// ============================================================
/// CROPS PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// ✅ PATTERN: repository → provider → controller → state → widgets
///
/// Provides crop list and management operations for a given farm.
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/crop_model.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';

/// Crop list state
class CropListState {
  final List<CropModel> crops;
  final bool isLoading;
  final String? errorMessage;
  final String? searchQuery;

  const CropListState({
    required this.crops,
    required this.isLoading,
    this.errorMessage,
    this.searchQuery,
  });

  factory CropListState.initial() => const CropListState(
        crops: [],
        isLoading: true,
      );

  List<CropModel> get filteredCrops {
    if (searchQuery == null || searchQuery!.isEmpty) return crops;
    final query = searchQuery!.toLowerCase();
    return crops.where((c) =>
      c.cropName.toLowerCase().contains(query) ||
      (c.variety?.toLowerCase().contains(query) ?? false)
    ).toList();
  }

  CropListState copyWith({
    List<CropModel>? crops,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
  }) {
    return CropListState(
      crops: crops ?? this.crops,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      searchQuery: searchQuery,
    );
  }
}

/// Crops notifier
class CropsNotifier extends StateNotifier<CropListState> {
  final FarmRepository _repository;
  final String? _farmId;

  CropsNotifier(this._repository, this._farmId)
      : super(CropListState.initial());

  Future<void> loadCrops() async {
    if (_farmId == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final crops = await _repository.getCrops(farmId: _farmId!);
      state = state.copyWith(crops: crops, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

/// Provider for crop list
final cropsProvider = StateNotifierProvider.family<CropsNotifier, CropListState, String?>(
  (ref, farmId) {
    final repository = ref.read(farmRepositoryProvider);
    return CropsNotifier(repository, farmId);
  },
);

/// Auto-loading crop provider based on farm context
final autoCropsProvider = Provider.family<AsyncValue<List<CropModel>>, String?>(
  (ref, farmId) {
    final cropsAsync = ref.watch(cropsProvider(farmId));
    return AsyncValue.data(cropsAsync.filteredCrops);
  },
);
