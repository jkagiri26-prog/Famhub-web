import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';

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
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ============================================================
/// FARM SELECTOR NOTIFIER (RIVERPOD 3 - NOTIFIER API)
/// ============================================================
class FarmSelectorNotifier extends Notifier<FarmSelectorState> {
  FarmRepository get _repository =>
      ref.read(farmRepositoryProvider);

  @override
  FarmSelectorState build() {
    return FarmSelectorState.initial();
  }

  /// Load farms for current user
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

  /// Select a farm
  void selectFarm(String farmId) {
    state = state.copyWith(selectedFarmId: farmId);
  }
}

/// ============================================================
/// PROVIDER (NOTIFIER VERSION)
/// ============================================================
final farmSelectorProvider =
    NotifierProvider<FarmSelectorNotifier, FarmSelectorState>(
  FarmSelectorNotifier.new,
);