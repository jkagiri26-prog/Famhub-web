/// ============================================================
/// FARM AI CONTEXT PROVIDER
/// ============================================================
///
/// 🧠 APPLICATION LAYER
///
/// Exposes structured farm context for AI features.
/// Every lifecycle stage provides appropriate context.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_ai_context_service.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_lifecycle_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_live_providers.dart';

/// Provides structured AI context for the current farm state.
final farmAiContextProvider = Provider<FarmAiContext?>((ref) {
  final lifecycle = ref.watch(farmLifecycleProvider);
  final context = ref.watch(farmContextProvider);
  final hierarchy = ref.watch(hierarchyProvider);

  const service = FarmAiContextService();

  // Build hierarchy path
  final segments = <String>[];
  if (hierarchy.entity != null) segments.add(hierarchy.entity!.farmName);
  if (hierarchy.field != null) segments.add(hierarchy.field!.fieldName);
  if (hierarchy.cropOrLivestock != null) {
    final entity = hierarchy.cropOrLivestock!;
    if (hierarchy.cropOrLivestockType == 'crop' && entity is CropEntity) {
      segments.add(entity.cropName);
    } else if (entity is LivestockEntity) {
      segments.add(entity.species);
    } else {
      segments.add(entity.toString());
    }
  }
  final hierarchyPath = segments.join(' → ');

  // Build recommendation strings
  final recommendationStrings = lifecycle.recommendations
      .map((r) => '[${r.severity.name.toUpperCase()}] ${r.title}: ${r.description}')
      .toList();

  // Use cached data from live providers where possible
  final cropsList = <dynamic>[];
  final livestockList = <dynamic>[];

  try {
    final cropsAsync = ref.read(farmCropsProvider);
    cropsAsync.whenData((crops) => cropsList.addAll(crops));
  } catch (_) {}

  try {
    final livestockAsync = ref.read(farmLivestockProvider);
    livestockAsync.whenData((livestock) => livestockList.addAll(livestock));
  } catch (_) {}

  return service.buildContext(
    stage: lifecycle.stage,
    hierarchyPath: hierarchyPath,
    cropEntities: cropsList,
    livestockEntities: livestockList,
    recentActivityCount: lifecycle.healthScore?.activityScore ?? 0,
    recommendations: recommendationStrings,
    healthScore: lifecycle.healthScore?.score,
    farmSize: context.farm?.size,
  );
});