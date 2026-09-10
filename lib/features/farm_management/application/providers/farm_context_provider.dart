import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_selector_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

/// ============================================================
/// FARM CONTEXT — OFFICIAL HIERARCHY CONTEXT
/// ============================================================
///
/// Carries the full hierarchical context:
///   Farm / Entity → Field / Block → Crop or Livestock → Activity → Report
///
/// Every dashboard widget, page, and provider receives these filter
/// values as context.
/// ============================================================
class FarmContext {
  /// Selected farm id — `farm_management.farms.id`.
  final String? farmId;
  final FarmEntity? farm;

  /// 🔑 Core identity (from the context engine / core.entities):
  /// users.profiles.id.
  final String? profileId;

  /// 🔑 Core identity: `core.entities.id` of the active entity.
  /// Distinct from [farmId] (a farm_management.farms row id).
  final String? entityId;

  /// 🔑 Core identity: `core.user_roles.id` of the active role.
  final String? roleId;

  /// Operational role/mode (e.g. 'farmer', 'trader') or null when unknown.
  final String? role;

  /// Field / Block level
  final String? fieldId;
  final FieldEntity? field;

  /// Crop or Livestock level
  final String? cropOrLivestockId;
  final String? cropOrLivestockType;

  const FarmContext({
    required this.farmId,
    required this.farm,
    this.profileId,
    this.entityId,
    this.roleId,
    this.role,
    this.fieldId,
    this.field,
    this.cropOrLivestockId,
    this.cropOrLivestockType,
  });

  /// True when a full drill-down path is selected (Farm → Field → Crop/Livestock)
  bool get hasFullSelection =>
      farmId != null && fieldId != null && cropOrLivestockId != null;
}

/// ============================================================
/// FARM CONTEXT PROVIDER
/// ============================================================
///
/// Resolves farm-specific context from:
///   1. Context Engine = identity source
///   2. Farm Selector = domain selection (Farm/Entity level)
///   3. Hierarchy Provider = field + crop/livestock selection
///
/// NOTE: RLS = data security layer (handled by Supabase)
/// ============================================================
final farmContextProvider = Provider<FarmContext>((ref) {
  final context = ref.watch(contextProvider);
  final hierarchy = ref.watch(hierarchyProvider);

  final selectedFarm = hierarchy.entity;

  return FarmContext(
    farmId: hierarchy.entityId,
    farm: selectedFarm,
    // 🔑 Real core identity from the context engine — profile/entity/role
    // are distinct domains and are carried separately.
    profileId: context.profileId,
    entityId: context.entityId,
    roleId: context.roleId,
    role: context.role,
    // 👇 HIERARCHY PROPAGATION
    fieldId: hierarchy.fieldId,
    field: hierarchy.field,
    cropOrLivestockId: hierarchy.cropOrLivestockId,
    cropOrLivestockType: hierarchy.cropOrLivestockType,
  );
});