/// ============================================================
/// FIELDS PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// 🏗️ OFFICIAL HIERARCHY:
///   Farm / Entity → **Field / Block** → Crop or Livestock → Activity → Report
///
/// ✅ PATTERN: repository → provider → state → widgets
///
/// Provides field registry, acreage/plot information, and utilization.
/// Automatically integrates with HierarchyProvider for selection.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

/// Field list state
class FieldListState {
  final List<FieldEntity> fields;
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
  List<FieldEntity> get cultivatedFields =>
      fields.where((f) => f.isCultivated).toList();

  /// Fields currently fallow/resting
  List<FieldEntity> get fallowFields =>
      fields.where((f) => !f.isCultivated).toList();

  FieldListState copyWith({
    List<FieldEntity>? fields,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FieldListState(
      fields: fields ?? this.fields,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// ============================================================
/// FIELDS NOTIFIER (RIVERPOD 3 - NOTIFIER API)
/// ============================================================
class FieldsNotifier extends Notifier<FieldListState> {
  FarmRepository get _repository =>
      ref.read(farmRepositoryProvider);

  @override
  FieldListState build() {
    // 🔑 SELF-HEALING LOAD: watch the selected farm and auto-load its
    // fields on every rebuild. The cascade coordinator invalidates this
    // provider whenever the hierarchy farm-level changes (including a
    // full reset). Without self-loading, a reset→reopen of the SAME farm
    // races: the manual loadFields() call is clobbered by the
    // coordinator's post-frame invalidate, leaving a fresh notifier stuck
    // in its initial isLoading:true state forever (infinite spinner).
    // Loading from build() reloads on every rebuild, so the provider can
    // never be left empty after an invalidation.
    final farmId = ref.watch(farmContextProvider.select((c) => c.farmId));
    if (farmId != null) {
      Future.microtask(() => loadFields(farmId: farmId));
    }
    return FieldListState.initial();
  }

  Future<void> loadFields({String? farmId}) async {
    final effectiveFarmId = farmId ?? ref.read(farmContextProvider).farmId;
    if (effectiveFarmId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final fields =
          await _repository.getFields(farmId: effectiveFarmId);

      state = state.copyWith(
        fields: fields,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Select a field in the hierarchy and load its crops/livestock
  Future<void> selectFieldAndLoad(FieldEntity field) async {
    ref.read(hierarchyProvider.notifier).selectField(field);
  }

  /// Clear field selection back to entity level
  void clearFieldSelection() {
    ref.read(hierarchyProvider.notifier).clearToEntity();
  }
}

/// ============================================================
/// PROVIDER (NOTIFIER)
/// ============================================================
final fieldsProvider =
    NotifierProvider<FieldsNotifier, FieldListState>(
  FieldsNotifier.new,
);