/// ============================================================
/// FARM KNOWLEDGE CONTEXT PROVIDER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/farm_management/application/providers/
///
/// Derives a canonical, module-neutral [KnowledgeContext] from the current
/// Farm Management hierarchy selection so the Knowledge Link surface can
/// resolve curated guides for the selected crop/livestock/location.
///
/// Mapping (only what Farm Management reliably holds — nothing is invented):
///   - Crop / Livestock asset → `variantId` (core.item_variants)
///   - Farm (ward → sub-county → county) → `locationId` (core.locations)
///
/// The entity/workspace identity (WHO is operating) is intentionally NOT
/// used here — it is not the Knowledge subject.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/knowledge_link/domain/models/knowledge_context.dart';

/// The canonical Knowledge context for the current farm hierarchy selection.
final farmKnowledgeContextProvider = Provider<KnowledgeContext>((ref) {
  final hierarchy = ref.watch(hierarchyProvider);
  final farm = hierarchy.entity;

  String? variantId;
  final type = hierarchy.cropOrLivestockType;
  if (type == 'crop' && hierarchy.cropOrLivestock is CropEntity) {
    variantId = (hierarchy.cropOrLivestock as CropEntity).variantId;
  } else if (type == 'livestock' && hierarchy.cropOrLivestock is LivestockEntity) {
    variantId = (hierarchy.cropOrLivestock as LivestockEntity).variantId;
  }

  // Most specific location first: ward → sub-county → county.
  final locationId = _firstNonEmpty(
    farm?.wardId,
    farm?.subCountyId,
    farm?.countyId,
  );

  return KnowledgeContext(
    variantId: _firstNonEmpty(variantId),
    locationId: locationId,
  );
});

String? _firstNonEmpty(String? first, [String? second, String? third]) {
  for (final value in [first, second, third]) {
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
