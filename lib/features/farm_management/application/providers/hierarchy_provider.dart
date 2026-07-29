/// ============================================================
/// HIERARCHY PROVIDER — Official Farm Management Hierarchy
/// ============================================================
///
/// ✅ Enforces the strict hierarchy:
///   Farm / Entity → Field / Block → Crop or Livestock → Activity → Report
///
/// This provider manages the current hierarchical context:
///   - entityId (farm/entity selected)
///   - fieldId (field/block selected)
///   - cropOrLivestockId (crop or livestock record selected)
///   - cropOrLivestockType ('crop' or 'livestock')
///
/// Every dashboard widget, page, and report receives these filter
/// values as context. No activity can be created without selecting
/// a Field/Block AND Crop/Livestock first.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';

/// ============================================================
/// HIERARCHY SELECTION STATE
/// ============================================================
///
/// Tracks the current position in the farm management hierarchy.
///
/// Path: Farm/Entity → Field/Block → Crop/Livestock → Activity → Report
/// ============================================================
class HierarchySelectionState {
  /// Selected Farm / Entity
  final FarmEntity? entity;

  /// Selected Field / Block
  final FieldEntity? field;

  /// Selected Crop or Livestock record
  final dynamic cropOrLivestock;

  /// Type discriminator: 'crop' or 'livestock'
  final String? cropOrLivestockType;

  /// Available farms list (loaded on bootstrap)
  final List<FarmEntity> farms;

  /// Monotonic version number — for cascade trigger detection
  final int version;

  const HierarchySelectionState({
    this.entity,
    this.field,
    this.cropOrLivestock,
    this.cropOrLivestockType,
    this.farms = const [],
    this.version = 0,
  });

  /// Breadcrumb representation
  List<String> get breadcrumbSegments {
    final segments = <String>[];
    if (entity != null) segments.add(entity!.farmName);
    if (field != null) segments.add(field!.fieldName);
    if (cropOrLivestock != null && cropOrLivestockType == 'crop') {
      segments.add((cropOrLivestock as CropEntity).cropName);
    } else if (cropOrLivestock != null && cropOrLivestockType == 'livestock') {
      segments.add((cropOrLivestock as LivestockEntity).species);
    }
    return segments;
  }

  /// Entity ID string
  String? get entityId => entity?.id;

  /// Field ID string
  String? get fieldId => field?.id;

  /// Crop/Livestock ID string
  String? get cropOrLivestockId {
    if (cropOrLivestock == null) return null;
    if (cropOrLivestockType == 'crop') {
      return (cropOrLivestock as CropEntity).id;
    } else if (cropOrLivestockType == 'livestock') {
      return (cropOrLivestock as LivestockEntity).id;
    }
    return null;
  }

  /// Whether a full selection chain exists (entity + field + crop/livestock)
  bool get hasFullSelection =>
      entity != null && field != null && cropOrLivestock != null;

  bool get hasEntity => entity != null;
  bool get hasField => field != null;
  bool get hasCropOrLivestock => cropOrLivestock != null;
  bool get farmsLoaded => farms.isNotEmpty;
  bool get isLoading => false;

  // ── Navigation Guards ──
  bool get canAddField => entity != null;
  bool get canAddCropOrLivestock => field != null;
  bool get canAddActivity => cropOrLivestock != null;

  HierarchySelectionState copyWith({
    FarmEntity? entity,
    FieldEntity? field,
    dynamic cropOrLivestock,
    String? cropOrLivestockType,
    List<FarmEntity>? farms,
    bool clearField = false,
    bool clearCropOrLivestock = false,
    int? version,
  }) {
    return HierarchySelectionState(
      entity: entity ?? this.entity,
      field: clearField ? null : (field ?? this.field),
      cropOrLivestock:
          clearCropOrLivestock ? null : (cropOrLivestock ?? this.cropOrLivestock),
      cropOrLivestockType:
          clearCropOrLivestock ? null : (cropOrLivestockType ?? this.cropOrLivestockType),
      farms: farms ?? this.farms,
      version: version ?? this.version + 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HierarchySelectionState &&
          entityId == other.entityId &&
          fieldId == other.fieldId &&
          cropOrLivestockId == other.cropOrLivestockId &&
          cropOrLivestockType == other.cropOrLivestockType;

  @override
  int get hashCode =>
      Object.hash(entityId, fieldId, cropOrLivestockId, cropOrLivestockType);
}

/// ============================================================
/// HIERARCHY NOTIFIER
/// ============================================================
class HierarchyNotifier extends Notifier<HierarchySelectionState> {
  @override
  HierarchySelectionState build() {
    return const HierarchySelectionState();
  }

  /// ── Load farms (called during bootstrap) ──
  void loadFarms(List<FarmEntity> farms) {
    if (farms.isEmpty) return;
    state = HierarchySelectionState(
      entity: farms.first,
      field: null,
      cropOrLivestock: null,
      cropOrLivestockType: null,
      farms: farms,
      version: state.version + 1,
    );
  }

  /// ── Select entity (farm) ──
  void selectEntity(FarmEntity entity) {
    if (state.entity?.id == entity.id && state.hasEntity) return;
    state = HierarchySelectionState(
      entity: entity,
      field: null,
      cropOrLivestock: null,
      cropOrLivestockType: null,
      farms: state.farms,
      version: state.version + 1,
    );
  }

  /// ── Force select entity by ID ──
  void selectEntityById(String entityId, {String? entityName}) {
    final farm = state.farms.cast<FarmEntity?>().firstWhere(
      (f) => f?.id == entityId,
      orElse: () => null,
    );
    if (farm != null) {
      selectEntity(farm);
    } else if (entityName != null) {
      selectEntity(FarmEntity(
        id: entityId,
        farmName: entityName,
        isActive: true,
        isVerified: false,
      ));
    }
  }

  /// ── Select field ──
  void selectField(FieldEntity field) {
    if (state.entity == null) return;
    state = state.copyWith(
      field: field,
      clearCropOrLivestock: true,
    );
  }

  /// Select a Crop record within the current field
  void selectCrop(CropEntity crop) {
    if (state.field == null) return;
    state = state.copyWith(
      cropOrLivestock: crop,
      cropOrLivestockType: 'crop',
    );
  }

  /// Select a Livestock record within the current field
  void selectLivestock(LivestockEntity livestock) {
    if (state.field == null) return;
    state = state.copyWith(
      cropOrLivestock: livestock,
      cropOrLivestockType: 'livestock',
    );
  }

  /// Clear the current selection back to entity level
  void clearToEntity() {
    state = HierarchySelectionState(
      entity: state.entity,
      field: null,
      cropOrLivestock: null,
      cropOrLivestockType: null,
    );
  }

  /// Clear the current selection back to field level
  void clearToField() {
    state = state.copyWith(
      clearCropOrLivestock: true,
    );
  }

  /// Reset everything
  void reset() {
    state = const HierarchySelectionState();
  }
}

/// ============================================================
/// PROVIDER
/// ============================================================
final hierarchyProvider =
    NotifierProvider<HierarchyNotifier, HierarchySelectionState>(
  HierarchyNotifier.new,
);

/// ============================================================
/// DERIVED PROVIDERS
/// ============================================================

/// True when a full drill-down path is selected
final hasFullHierarchyProvider = Provider<bool>((ref) {
  return ref.watch(hierarchyProvider).hasFullSelection;
});

/// Current entityId from hierarchy
final currentEntityIdProvider = Provider<String?>((ref) {
  return ref.watch(hierarchyProvider).entityId;
});

/// Current fieldId from hierarchy
final currentFieldIdProvider = Provider<String?>((ref) {
  return ref.watch(hierarchyProvider).fieldId;
});

/// Current cropOrLivestockId from hierarchy
final currentCropOrLivestockIdProvider = Provider<String?>((ref) {
  return ref.watch(hierarchyProvider).cropOrLivestockId;
});

/// Breadcrumb segments for UI display
final breadcrumbSegmentsProvider = Provider<List<String>>((ref) {
  return ref.watch(hierarchyProvider).breadcrumbSegments;
});

final canAddFieldProvider = Provider<bool>((ref) {
  return ref.watch(hierarchyProvider).canAddField;
});

final canAddCropOrLivestockProvider = Provider<bool>((ref) {
  return ref.watch(hierarchyProvider).canAddCropOrLivestock;
});

final canAddActivityProvider = Provider<bool>((ref) {
  return ref.watch(hierarchyProvider).canAddActivity;
});
