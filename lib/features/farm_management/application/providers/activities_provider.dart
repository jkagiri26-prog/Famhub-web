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
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/utils/display_text.dart';

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

      // Client-side filtering by UI hierarchy context.
      //
      // ⚠️ DOCUMENTED LIMITATION: the activities table has no
      // field_id / crop_or_livestock_id columns, and the frontend's
      // `assets` table is machinery/equipment (no field_id/variant_id),
      // so field/crop hierarchy CANNOT be reconstructed after a reload
      // or app restart. After reload `a.fieldId`/`a.cropOrLivestockId`
      // are null. The filter therefore treats null context as "unknown —
      // include" (safe: it never hides an activity). Field/crop-level
      // narrowing only applies to activities created within the current
      // session. Full hierarchy filtering after reload requires a
      // backend linkage contract (see report: backend dependencies).
      final filtered = activities.where((a) {
        final matchesField = hierarchy.fieldId == null ||
            a.fieldId == null ||
            a.fieldId == hierarchy.fieldId;
        final matchesCrop = hierarchy.cropOrLivestockId == null ||
            a.cropOrLivestockId == null ||
            a.cropOrLivestockId == hierarchy.cropOrLivestockId;
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

// ─────────────────────────────────────────────────────────────
// GLOBAL ACTIVITY JOURNAL (all user crop/livestock activities)
// ─────────────────────────────────────────────────────────────

/// One activity enriched with its owning farm/field and the crop/livestock
/// asset it was performed on (resolved through activities.asset_id →
/// farm_management.assets → field → farm).
class GlobalActivityEntry {
  final ActivityModel activity;

  /// Display name of the activity type (from farm_management.activity_types).
  final String typeName;

  final FarmEntity farm;
  final FieldEntity? field;
  final Object asset;
  final String assetType; // 'crop' | 'livestock'
  final String assetLabel;

  const GlobalActivityEntry({
    required this.activity,
    required this.typeName,
    required this.farm,
    this.field,
    required this.asset,
    required this.assetType,
    required this.assetLabel,
  });

  String get farmName => farm.farmName;
  String? get fieldName => field?.fieldName;
  String get assetId => activity.assetId ?? activity.cropOrLivestockId ?? '';
}

/// Loads the current user's activity journal across ALL farms by reusing
/// the existing authorized single-farm repository path (no client user_id).
///
/// Each activity is resolved back to its asset → field → farm so the UI can
/// show type, asset, farm, field and time. Newest first. RLS remains the
/// security boundary.
final allUserActivitiesProvider = FutureProvider<List<GlobalActivityEntry>>(
  (ref) async {
  final repository = ref.read(farmRepositoryProvider);

  Map<String, String> typeNames = const {};
  try {
    typeNames = await repository.getActivityTypeNames();
  } catch (_) {
    typeNames = const {};
  }

  final farms = await repository.getUserFarms();
  final entries = <GlobalActivityEntry>[];

  for (final farm in farms) {
    List<ActivityModel> activities;
    try {
      activities = await repository.getActivities(farmId: farm.id);
    } catch (_) {
      continue;
    }
    if (activities.isEmpty) continue;

    final cropById = <String, CropEntity>{};
    final livestockById = <String, LivestockEntity>{};
    final fieldsById = <String, FieldEntity>{};
    try {
      final crops = await repository.getCrops(farmId: farm.id);
      for (final crop in crops) {
        cropById[crop.id] = crop;
      }
    } catch (_) {}
    try {
      final livestock = await repository.getLivestock(farmId: farm.id);
      for (final animal in livestock) {
        livestockById[animal.id] = animal;
      }
    } catch (_) {}
    try {
      final fields = await repository.getFields(farmId: farm.id);
      for (final field in fields) {
        fieldsById[field.id] = field;
      }
    } catch (_) {}

    for (final activity in activities) {
      final assetKey = activity.assetId ?? activity.cropOrLivestockId;
      if (assetKey == null) continue;

      FieldEntity? field;
      Object? asset;
      var assetType = '';
      var assetLabel = '';

      final crop = cropById[assetKey];
      if (crop != null) {
        asset = crop;
        assetType = 'crop';
        assetLabel = assetDisplayTitle(crop.cropName);
        if (crop.fieldId != null) field = fieldsById[crop.fieldId];
        entries.add(_entry(activity, typeNames, farm, field, asset, assetType,
            assetLabel));
        continue;
      }
      final animal = livestockById[assetKey];
      if (animal != null) {
        asset = animal;
        assetType = 'livestock';
        assetLabel = assetDisplayTitle(animal.species);
        if (animal.fieldId != null) field = fieldsById[animal.fieldId];
        entries.add(_entry(activity, typeNames, farm, field, asset, assetType,
            assetLabel));
      }
    }
  }

  entries.sort(
    (a, b) => b.activity.performedAt.compareTo(a.activity.performedAt),
  );
  return entries.length > 400 ? entries.take(400).toList() : entries;
});

GlobalActivityEntry _entry(
  ActivityModel activity,
  Map<String, String> typeNames,
  FarmEntity farm,
  FieldEntity? field,
  Object asset,
  String assetType,
  String assetLabel,
) {
  return GlobalActivityEntry(
    activity: activity,
    typeName: activityTypeDisplay(
      typeNames[activity.activityTypeId] ?? activity.activityTypeId,
    ),
    farm: farm,
    field: field,
    asset: asset,
    assetType: assetType,
    assetLabel: assetLabel,
  );
}