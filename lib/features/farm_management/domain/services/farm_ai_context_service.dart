/// ============================================================
/// FARM AI CONTEXT SERVICE (Domain Layer)
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Prepares structured, serializable context for AI assistants.
/// Every lifecycle stage exposes:
///   - Current stage and hierarchy
///   - Current crops/livestock with status
///   - Recent activities and trends
///   - Outstanding recommendations
///   - Weather context (if available)
///   - Health score
///
/// This ensures the module is AI-ready without redesign when
/// AI features are introduced.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/enums/farm_lifecycle_stage.dart';
import 'package:famhub_app/features/farm_management/domain/enums/crop_status.dart';

/// Structured context for AI consumption
class FarmAiContext {
  /// Current lifecycle stage
  final String stage;

  /// Stage priority
  final int stagePriority;

  /// Current selected hierarchy path
  final String hierarchyPath;

  /// Current crops summary
  final List<CropSummary> crops;

  /// Current livestock summary
  final List<LivestockSummary> livestock;

  /// Recent activity count
  final int recentActivityCount;

  /// Days since last activity
  final int? daysSinceLastActivity;

  /// Active recommendations
  final List<String> recommendations;

  /// Health score (0-100)
  final int? healthScore;

  /// Whether the farm is in an active production phase
  final bool isActive;

  /// Farm size
  final double? farmSize;

  /// Whether action is needed
  final bool requiresAction;

  const FarmAiContext({
    required this.stage,
    required this.stagePriority,
    required this.hierarchyPath,
    required this.crops,
    required this.livestock,
    required this.recentActivityCount,
    this.daysSinceLastActivity,
    required this.recommendations,
    this.healthScore,
    required this.isActive,
    this.farmSize,
    required this.requiresAction,
  });

  /// Serialize to a Map for AI API consumption
  Map<String, dynamic> toJson() {
    return {
      'stage': stage,
      'stage_priority': stagePriority,
      'hierarchy_path': hierarchyPath,
      'crops': crops.map((c) => c.toJson()).toList(),
      'livestock': livestock.map((l) => l.toJson()).toList(),
      'recent_activity_count': recentActivityCount,
      'days_since_last_activity': daysSinceLastActivity,
      'recommendations': recommendations,
      'health_score': healthScore,
      'is_active': isActive,
      'farm_size': farmSize,
      'requires_action': requiresAction,
    };
  }
}

/// Summary of a crop for AI context
class CropSummary {
  final String name;
  final String? variety;
  final String status;
  final double? areaPlanted;
  final String? expectedHarvestDate;

  const CropSummary({
    required this.name,
    this.variety,
    required this.status,
    this.areaPlanted,
    this.expectedHarvestDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'variety': variety,
      'status': status,
      'area_planted': areaPlanted,
      'expected_harvest_date': expectedHarvestDate,
    };
  }
}

/// Summary of livestock for AI context
class LivestockSummary {
  final String species;
  final String? breed;
  final int count;
  final String? healthStatus;

  const LivestockSummary({
    required this.species,
    this.breed,
    required this.count,
    this.healthStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'species': species,
      'breed': breed,
      'count': count,
      'health_status': healthStatus,
    };
  }
}

/// Builds structured AI context from farm data
class FarmAiContextService {
  const FarmAiContextService();

  /// Build a structured AI context object from farm data.
  /// Returns null if insufficient data is available.
  FarmAiContext? buildContext({
    required FarmLifecycleStage stage,
    required String hierarchyPath,
    required List<dynamic> cropEntities,
    required List<dynamic> livestockEntities,
    required int recentActivityCount,
    int? daysSinceLastActivity,
    required List<String> recommendations,
    int? healthScore,
    double? farmSize,
  }) {
    if (stage == FarmLifecycleStage.unknown && cropEntities.isEmpty && livestockEntities.isEmpty) {
      return null;
    }

    return FarmAiContext(
      stage: stage.label,
      stagePriority: stage.priority,
      hierarchyPath: hierarchyPath,
      crops: cropEntities.map((c) => _buildCropSummary(c)).toList(),
      livestock: livestockEntities.map((l) => _buildLivestockSummary(l)).toList(),
      recentActivityCount: recentActivityCount,
      daysSinceLastActivity: daysSinceLastActivity,
      recommendations: recommendations,
      healthScore: healthScore,
      isActive: stage.isActive,
      farmSize: farmSize,
      requiresAction: stage.requiresAction,
    );
  }

  CropSummary _buildCropSummary(dynamic crop) {
    // Accept both CropEntity-like objects and Maps
    if (crop is Map<String, dynamic>) {
      return CropSummary(
        name: crop['cropName'] as String? ?? crop['crop_name'] as String? ?? 'Unknown',
        variety: crop['variety'] as String?,
        status: crop['status']?.toString() ?? 'unknown',
        areaPlanted: (crop['areaPlanted'] as num? ?? crop['area_planted'] as num?)?.toDouble(),
        expectedHarvestDate: crop['expectedHarvestDate']?.toString() ?? crop['expected_harvest_date']?.toString(),
      );
    }
    // Assume it has named properties
    return CropSummary(
      name: crop.cropName ?? 'Unknown',
      variety: crop.variety,
      status: crop.status?.name ?? 'unknown',
      areaPlanted: crop.areaPlanted,
      expectedHarvestDate: crop.expectedHarvestDate?.toIso8601String(),
    );
  }

  LivestockSummary _buildLivestockSummary(dynamic livestock) {
    if (livestock is Map<String, dynamic>) {
      return LivestockSummary(
        species: livestock['species'] as String? ?? 'Unknown',
        breed: livestock['breed'] as String?,
        count: livestock['count'] as int? ?? 0,
        healthStatus: livestock['healthStatus'] as String? ?? livestock['health_status'] as String?,
      );
    }
    return LivestockSummary(
      species: livestock.species ?? 'Unknown',
      breed: livestock.breed,
      count: livestock.count ?? 0,
      healthStatus: livestock.healthStatus,
    );
  }
}