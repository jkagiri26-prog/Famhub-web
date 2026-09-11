/// ============================================================
/// FARM SELECTOR PROVIDER — Simplified to Farm List Only
/// ============================================================
///
/// 🏗️ ARCHITECTURE UPDATE:
///   hierarchyProvider is now the SINGLE source of truth
///   for farm selection. This provider ONLY manages the farm
///   list loading state. It does NOT hold selectedFarmId.
///
///   Selection is handled by hierarchyProvider.selectEntity().
///
///   Bootstrap flow:
///     loadFarms() → farms list loaded → hierarchy.loadFarms(farms)
///     → hierarchy auto-selects first farm
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

/// Farm list loading state only — no selection state
class FarmSelectorState {
  final List<FarmEntity> farms;
  final bool isLoading;
  final String? errorMessage;

  const FarmSelectorState({
    required this.farms,
    required this.isLoading,
    this.errorMessage,
  });

  factory FarmSelectorState.initial() => const FarmSelectorState(
        farms: [],
        isLoading: true,
      );

  FarmSelectorState copyWith({
    List<FarmEntity>? farms,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FarmSelectorState(
      farms: farms ?? this.farms,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ============================================================
/// FARM SELECTOR NOTIFIER (RIVERPOD 3 - NOTIFIER API)
/// ============================================================
///
/// Loads farms and syncs into hierarchyProvider.
/// Does NOT hold selectedFarmId — that's exclusively in hierarchyProvider.
/// ============================================================
class FarmSelectorNotifier extends Notifier<FarmSelectorState> {
  FarmRepository get _repository =>
      ref.read(farmRepositoryProvider);

  @override
  FarmSelectorState build() {
    // 🔑 IDENTITY-ALIGNED FETCH:
    // The real entity context resolves asynchronously (auth → profile →
    // core.entity_context_sessions → core.entities) and changes again on a
    // workspace/entity switch. Farm visibility is entity-scoped, so the farm
    // list must be (re)fetched whenever the active entity context changes —
    // otherwise the selector stays in its initial loading state and every
    // tab shows no data. The page/bootstrap may still call loadFarms().
    ref.watch(contextProvider.select((c) => c.entityId));
    final isResolving = ref.watch(contextProvider.select((c) => c.isLoading));
    if (!isResolving) {
      Future.microtask(loadFarms);
    }
    return FarmSelectorState.initial();
  }

  /// Load farms and auto-select first into hierarchy
  Future<void> loadFarms() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final farms = await _repository.getUserFarms();

      state = state.copyWith(
        farms: farms,
        isLoading: false,
      );

      // SYNC with hierarchyProvider — load farm list and auto-select first
      if (farms.isNotEmpty) {
        ref.read(hierarchyProvider.notifier).loadFarms(farms);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

/// ============================================================
/// PROVIDER (NOTIFIER VERSION)
/// ============================================================
final farmSelectorProvider =
    NotifierProvider<FarmSelectorNotifier, FarmSelectorState>(
  FarmSelectorNotifier.new,
);

/// ============================================================
/// DERIVED: selected farm ID from hierarchy (single source of truth)
/// ============================================================
final selectedFarmIdProvider = Provider<String?>((ref) {
  return ref.watch(hierarchyProvider).entityId;
});