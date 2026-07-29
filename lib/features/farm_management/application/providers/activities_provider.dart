/// ============================================================
/// ACTIVITIES PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// 🏗️ OFFICIAL HIERARCHY:
///   Farm / Entity → Field / Block → Crop or Livestock → **Activity** → Report
///
/// ✅ PATTERN: repository → provider → state → widgets
///
/// Provides farm activity timeline and management operations.
/// Activities are filtered by the current hierarchy context client-side:
///   - farmId (required, resolved through asset/plan relationship)
///   - fieldId, cropOrLivestockId (UI context only — resolved from asset)
///
/// ⚠️ No activity can be created without a selected Crop/Livestock.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

/// Activity list state
class ActivityListState {
  final List<ActivityModel> activities;
  final bool isLoading;
  final String? errorMessage;

  /// Current hierarchy filter context (UI-only, NOT backend columns)
  final String? fieldId;
  final String? cropOrLivestockId;

  const ActivityListState({
    required this.activities,
    required this.isLoading,
    this.errorMessage,
    this.fieldId,
    this.cropOrLivestockId,
  });

  factory ActivityListState.initial() => const ActivityListState(
        activities: [],
        isLoading: true,
      );

  ActivityListState copyWith({
    List<ActivityModel>? activities,
    bool? isLoading,
    String? errorMessage,
    String? fieldId,
    String? cropOrLivestockId,
  }) {
    return ActivityListState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      fieldId: fieldId ?? this.fieldId,
      cropOrLivestockId: cropOrLivestockId ?? this.cropOrLivestockId,
    );
  }
}

/// ============================================================
/// ACTIVITIES NOTIFIER (RIVERPOD 3 - NOTIFIER API)
/// ============================================================
class ActivitiesNotifier extends Notifier<ActivityListState> {
  FarmRepository get _repository => ref.read(farmRepositoryProvider);

  @override
  ActivityListState build() {
    // Auto-watch farm context and hierarchy so the provider refreshes
    ref.watch(farmContextProvider);
    ref.watch(hierarchyProvider);
    return ActivityListState.initial();
  }

  /// Load activities for the current farm.
  /// UI-side filtering by hierarchy level (field, crop/livestock) is applied
  /// client-side after fetch, since the activities table does not have
  /// farm_id, field_id, or crop_or_livestock_id columns.
  Future<void> loadActivities() async {
    final farmId = ref.read(farmContextProvider).farmId;
    final hierarchy = ref.read(hierarchyProvider);

    if (farmId == null) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final activities = await _repository.getActivities(farmId: farmId);

      // Client-side filtering by UI hierarchy context
      final filtered = activities.where((a) {
        final matchesField = hierarchy.fieldId == null || a.fieldId == null || a.fieldId == hierarchy.fieldId;
        final matchesCrop = hierarchy.cropOrLivestockId == null || a.cropOrLivestockId == null || a.cropOrLivestockId == hierarchy.cropOrLivestockId;
        return matchesField && matchesCrop;
      }).toList();

      state = state.copyWith(
        activities: filtered,
        isLoading: false,
        fieldId: hierarchy.fieldId,
        cropOrLivestockId: hierarchy.cropOrLivestockId,
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
final activitiesProvider =
    NotifierProvider<ActivitiesNotifier, ActivityListState>(
  ActivitiesNotifier.new,
);