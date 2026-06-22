/// ============================================================
/// PRODUCTION PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// ✅ PATTERN: repository → provider → state → widgets
///
/// Provides production records, yield summaries, and analytics.
/// This page becomes the bridge toward Marketplace integration.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/production_model.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';

/// Production state
class ProductionState {
  final List<ProductionModel> records;
  final bool isLoading;
  final String? errorMessage;

  const ProductionState({
    required this.records,
    required this.isLoading,
    this.errorMessage,
  });

  factory ProductionState.initial() => const ProductionState(
        records: [],
        isLoading: true,
      );

  /// Total quantity from all records
  double get totalQuantity =>
      records.fold(0.0, (sum, r) => sum + (r.quantity ?? 0));

  /// Number of production entries
  int get recordCount => records.length;

  ProductionState copyWith({
    List<ProductionModel>? records,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProductionState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ============================================================
/// PRODUCTION NOTIFIER (RIVERPOD 3 - NOTIFIER API)
/// ============================================================
class ProductionNotifier extends Notifier<ProductionState> {
  FarmRepository get _repository =>
      ref.read(farmRepositoryProvider);

  @override
  ProductionState build() {
    return ProductionState.initial();
  }

  Future<void> loadProductionRecords({String? farmId}) async {
    final effectiveFarmId = farmId ?? ref.read(farmContextProvider).farmId;
    if (effectiveFarmId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final records =
          await _repository.getProductionRecords(farmId: effectiveFarmId);

      state = state.copyWith(
        records: records,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

/// ============================================================
/// PROVIDER (NOTIFIER)
/// ============================================================
final productionProvider =
    NotifierProvider<ProductionNotifier, ProductionState>(
  ProductionNotifier.new,
);