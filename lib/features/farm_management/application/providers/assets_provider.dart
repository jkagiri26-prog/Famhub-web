/// ============================================================
/// ASSETS PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// ✅ PATTERN: repository → provider → state → widgets
///
/// Provides farm asset registry and management operations.
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/asset_model.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';

/// Asset list state
class AssetListState {
  final List<AssetModel> assets;
  final bool isLoading;
  final String? errorMessage;
  final String? typeFilter;

  const AssetListState({
    required this.assets,
    required this.isLoading,
    this.errorMessage,
    this.typeFilter,
  });

  factory AssetListState.initial() => const AssetListState(
        assets: [],
        isLoading: true,
      );

  List<AssetModel> get filteredAssets {
    if (typeFilter == null || typeFilter!.isEmpty) return assets;
    return assets.where((a) => a.assetType == typeFilter).toList();
  }

  /// Unique asset types
  List<String> get assetTypes =>
      assets.map((a) => a.assetType).toSet().toList()..sort();

  /// Assets needing maintenance (90+ days since last)
  List<AssetModel> get needsMaintenance =>
      assets.where((a) {
        if (a.daysSinceMaintenance == null) return true;
        return a.daysSinceMaintenance! >= 90;
      }).toList();

  AssetListState copyWith({
    List<AssetModel>? assets,
    bool? isLoading,
    String? errorMessage,
    String? typeFilter,
  }) {
    return AssetListState(
      assets: assets ?? this.assets,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      typeFilter: typeFilter,
    );
  }
}

/// Assets notifier
class AssetsNotifier extends StateNotifier<AssetListState> {
  final FarmRepository _repository;
  final String? _farmId;

  AssetsNotifier(this._repository, this._farmId)
      : super(AssetListState.initial());

  Future<void> loadAssets() async {
    if (_farmId == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final assets = await _repository.getAssets(farmId: _farmId!);
      state = state.copyWith(assets: assets, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setTypeFilter(String? type) {
    state = state.copyWith(typeFilter: type);
  }
}

/// Provider for asset list
final assetsProvider = StateNotifierProvider.family<AssetsNotifier, AssetListState, String?>(
  (ref, farmId) {
    final repository = ref.read(farmRepositoryProvider);
    return AssetsNotifier(repository, farmId);
  },
);
