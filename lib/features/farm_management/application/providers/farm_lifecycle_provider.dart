/// ============================================================
/// FARM LIFECYCLE PROVIDER
/// ============================================================
///
/// 🧠 APPLICATION LAYER
///
/// Automatically determines the farm's lifecycle stage and health score.
/// Integrates with the existing hierarchy, live data providers,
/// and recommendation engine.
///
/// This is the central integration point for lifecycle-aware features.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/enums/farm_lifecycle_stage.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_lifecycle_detector.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_health_score_service.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_recommendation_engine.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';

// ============================================================
// LIFECYCLE STATE
// ============================================================

/// Comprehensive lifecycle state for a farm
class FarmLifecycleState {
  /// The automatically determined lifecycle stage
  final FarmLifecycleStage stage;

  /// The health score result
  final HealthScoreResult? healthScore;

  /// List of contextual recommendations
  final List<FarmRecommendation> recommendations;

  /// Whether the lifecycle data is still loading
  final bool isLoading;

  /// Error message if detection failed
  final String? errorMessage;

  const FarmLifecycleState({
    required this.stage,
    this.healthScore,
    this.recommendations = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  factory FarmLifecycleState.initial() => const FarmLifecycleState(
        stage: FarmLifecycleStage.unknown,
        isLoading: true,
      );

  /// Next logical action for the current stage
  String? get nextActionLabel {
    if (recommendations.isEmpty) return null;
    return recommendations.first.actionLabel;
  }

  String? get nextActionRoute {
    if (recommendations.isEmpty) return null;
    return recommendations.first.actionRoute;
  }

  FarmLifecycleState copyWith({
    FarmLifecycleStage? stage,
    HealthScoreResult? healthScore,
    List<FarmRecommendation>? recommendations,
    bool? isLoading,
    String? errorMessage,
    bool clearHealthScore = false,
    bool clearRecommendations = false,
  }) {
    return FarmLifecycleState(
      stage: stage ?? this.stage,
      healthScore:
          clearHealthScore ? null : (healthScore ?? this.healthScore),
      recommendations: clearRecommendations
          ? const []
          : (recommendations ?? this.recommendations),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ============================================================
// LIFECYCLE NOTIFIER
// ============================================================

class FarmLifecycleNotifier extends Notifier<FarmLifecycleState> {
  final FarmLifecycleDetector _detector = const FarmLifecycleDetector();
  final FarmHealthScoreService _healthService =
      const FarmHealthScoreService();
  final FarmRecommendationEngine _recommendationEngine =
      const FarmRecommendationEngine();

  @override
  FarmLifecycleState build() {
    ref.listen(farmContextProvider, (previous, next) {
      if (previous?.farmId != next.farmId) {
        refreshLifecycle();
      }
    });
    ref.listen<int>(_hierarchyVersionSelector, (previous, next) {
      if (previous != null && next != previous) {
        refreshLifecycle();
      }
    });
    return FarmLifecycleState.initial();
  }

  static final _hierarchyVersionSelector = Provider<int>((ref) {
    return ref.watch(hierarchyProvider.select((s) => s.version));
  });

  Future<void> refreshLifecycle() async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId == null) {
      state = const FarmLifecycleState(
        stage: FarmLifecycleStage.unknown,
      );
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repository = ref.read(farmRepositoryProvider);

      final fields = await repository.getFields(farmId: farmId);
      final crops = await repository.getCrops(farmId: farmId);
      final livestock = await repository.getLivestock(farmId: farmId);
      final activities = await repository.getActivities(farmId: farmId);
      final productionRecords =
          await repository.getProductionRecords(farmId: farmId);

      final hasReports = productionRecords.isNotEmpty;

      final detectionInput = LifecycleDetectionInput(
        hasField: fields.isNotEmpty,
        hasCrop: crops.isNotEmpty,
        hasLivestock: livestock.isNotEmpty,
        activityCount: activities.length,
        productionRecordCount: productionRecords.length,
        hasReports: hasReports,
        uniqueActivityTypes:
            activities.map((a) => a.activityTypeId).toSet().length,
      );
      final stage = _detector.detect(detectionInput);

      final daysSinceLastActivity = activities.isNotEmpty
          ? DateTime.now().difference(
              activities
                  .map((a) => a.performedAt)
                  .reduce((a, b) => a.isAfter(b) ? a : b),
            ).inDays
          : null;

      final recentActivities = activities
          .where((a) =>
              a.performedAt
                  .isAfter(DateTime.now().subtract(const Duration(days: 7))))
          .length;

      final healthInput = HealthScoreInput(
        totalActivities: activities.length,
        recentActivities: recentActivities,
        overdueTasks: 0,
        totalProduction: productionRecords.fold<double>(
            0, (s, p) => s + (p.quantity ?? 0)),
        stockValue: 0,
        financialRecordCount: 0,
        daysSinceLastActivity: daysSinceLastActivity,
        hasCropOrLivestock: crops.isNotEmpty || livestock.isNotEmpty,
      );
      final healthScore = _healthService.calculate(healthInput);

      // Stock threshold tracking: AssetEntity has no quantity field
      // (it represents machinery/equipment, not inventory).
      // Stock/inventory quantity lives in a separate module.
      const bool hasStockBelowThreshold = false;

      const int overdueTaskCount = 0;
      final int? daysSinceLastFinancialRecord = null;

      final recommendationInput = RecommendationInput(
        stage: stage,
        hasCrop: crops.isNotEmpty,
        hasLivestock: livestock.isNotEmpty,
        hasField: fields.isNotEmpty,
        activityCount: activities.length,
        daysSinceLastActivity: daysSinceLastActivity ?? 999,
        hasPendingHarvest: crops.any((c) =>
            c.expectedHarvestDate != null &&
            c.expectedHarvestDate!
                    .difference(DateTime.now())
                    .inDays <=
                14),
        hasProductionRecords: productionRecords.isNotEmpty,
        hasReports: hasReports,
        overdueTaskCount: overdueTaskCount,
        hasStockBelowThreshold: hasStockBelowThreshold,
        daysSinceLastFinancialRecord: daysSinceLastFinancialRecord,
      );
      final recommendations =
          _recommendationEngine.generate(recommendationInput);

      state = FarmLifecycleState(
        stage: stage,
        healthScore: healthScore,
        recommendations: recommendations,
        isLoading: false,
      );
    } catch (e) {
      state = FarmLifecycleState(
        stage: FarmLifecycleStage.unknown,
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

// ============================================================
// PROVIDER
// ============================================================

final farmLifecycleProvider =
    NotifierProvider<FarmLifecycleNotifier, FarmLifecycleState>(
  FarmLifecycleNotifier.new,
);

// ============================================================
// DERIVED PROVIDERS
// ============================================================

final currentLifecycleStageProvider = Provider<FarmLifecycleStage>((ref) {
  return ref.watch(farmLifecycleProvider).stage;
});

final farmHealthScoreProvider = Provider<HealthScoreResult?>((ref) {
  return ref.watch(farmLifecycleProvider).healthScore;
});

final farmRecommendationsProvider =
    Provider<List<FarmRecommendation>>((ref) {
  return ref.watch(farmLifecycleProvider).recommendations;
});

final farmNextActionProvider = Provider<FarmRecommendation?>((ref) {
  final state = ref.watch(farmLifecycleProvider);
  if (state.recommendations.isEmpty) return null;
  return state.recommendations.first;
});