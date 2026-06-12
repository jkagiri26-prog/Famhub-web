/// ============================================================
/// FIELDS PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// ✅ PATTERN: repository → provider → state → widgets
///
/// Provides field registry, acreage/plot information, and utilization.
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/field_model.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';

/// Field list state
class FieldListState {
  final List<FieldModel> fields;
  final bool isLoading;
  final String? errorMessage;

  const FieldListState({
    required this.fields,
    required this.isLoading,
    this.errorMessage,
  });

  factory FieldListState.initial() => const FieldListState(
        fields: [],
        isLoading: true,
      );

  /// Total acreage of all fields
  double get totalAcreage =>
      fields.fold(0.0, (sum, f) => sum + (f.acreage ?? 0));

  /// Fields currently being cultivated
  List<FieldModel> get cultivatedFields =>
      fields.where((f) => f.isCultivated).toList();

  /// Fields currently fallow/resting
  List<FieldModel> get fallowFields =>
      fields.where((f) => !f.isCultivated).toList();

  FieldListState copyWith({
    List<FieldModel>? fields,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FieldListState(
      fields: fields ?? this.fields,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Fields notifier
class FieldsNotifier extends StateNotifier<FieldListState> {
  final FarmRepository _repository;
  final String? _farmId;

  FieldsNotifier(this._repository, this._farmId)
      : super(FieldListState.initial());

  Future<void> loadFields() async {
    if (_farmId == null) return;
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final fields = await _repository.getFields(farmId: _farmId!);
      state = state.copyWith(fields: fields, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

/// Provider for field list
final fieldsProvider = StateNotifierProvider.family<FieldsNotifier, FieldListState, String?>(
  (ref, farmId) {
    final repository = ref.read(farmRepositoryProvider);
    return FieldsNotifier(repository, farmId);
  },
);
