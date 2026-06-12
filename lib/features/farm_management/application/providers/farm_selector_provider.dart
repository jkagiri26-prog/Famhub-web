import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/infrastructure/repositories/farm_repository_impl.dart';

class FarmSelectorState {
  final List<FarmEntity> farms;
  final String? selectedFarmId;
  final bool isLoading;
  final String? errorMessage;

  const FarmSelectorState({
    required this.farms,
    required this.selectedFarmId,
    required this.isLoading,
    this.errorMessage,
  });

  factory FarmSelectorState.initial() => const FarmSelectorState(
        farms: [],
        selectedFarmId: null,
        isLoading: true,
        errorMessage: null,
      );

  FarmSelectorState copyWith({
    List<FarmEntity>? farms,
    String? selectedFarmId,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FarmSelectorState(
      farms: farms ?? this.farms,
      selectedFarmId: selectedFarmId ?? this.selectedFarmId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Manages farm selection state and loads user's farms.
class FarmSelectorNotifier extends StateNotifier<FarmSelectorState> {
  final FarmRepository _repository;

  FarmSelectorNotifier(this._repository) : super(FarmSelectorState.initial());

  /// Load farms for the current user.
  Future<void> loadFarms() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final farms = await _repository.getUserFarms();
      state = state.copyWith(
        farms: farms,
        isLoading: false,
        selectedFarmId: farms.isNotEmpty ? farms.first.id : null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Select a farm by ID.
  void selectFarm(String farmId) {
    state = state.copyWith(selectedFarmId: farmId);
  }
}

/// Provider for farm selector state.
final farmSelectorProvider = StateNotifierProvider<FarmSelectorNotifier, FarmSelectorState>((ref) {
  final repository = ref.read(farmRepositoryProvider);
  return FarmSelectorNotifier(repository);
});