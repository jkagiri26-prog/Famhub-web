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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/production_model.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';

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
      errorMessage: errorMessage,
    );
  }
}

/// Production notifier
class ProductionNotifier extends StateNotifier<ProductionState> {
  final FarmRepository _repository;
  final String? _farmId;

  ProductionNotifier(this._repository, this._farmId)
      : super(ProductionState.initial());

  Future<void> loadProduction() async {
    if (_farmId == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final records = await _repository.getProductionRecords(farmId: _farmId!);
      state = state.copyWith(records: records, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

/// Provider for production records
final productionProvider = StateNotifierProvider.family<ProductionNotifier, ProductionState, String?>(
  (ref, farmId) {
    final repository = ref.read(farmRepositoryProvider);
    return ProductionNotifier(repository, farmId);
  },
);
