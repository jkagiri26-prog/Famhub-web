import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/farm_entity.dart';
import '../../infrastructure/repositories/farm_repository_impl.dart';

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