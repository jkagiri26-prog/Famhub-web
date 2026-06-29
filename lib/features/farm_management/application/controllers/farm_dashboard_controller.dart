/// ============================================================
/// FARM DASHBOARD CONTROLLER
/// ============================================================
///
/// 🧠 APPLICATION LAYER — controller
///
/// Orchestrates farm dashboard data loading and actions.
/// - Reads farm context
/// - Loads dashboard summary + today's activities
/// - Provides action methods for production, activities, marketplace sync
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/state/farm_dashboard_state.dart';

/// Dashboard controller:
/// - Reads farm context
/// - Loads dashboard data (summary + activities)
/// - Executes farm actions (production, activities, marketplace sync)
class FarmDashboardController extends AsyncNotifier<FarmDashboardState> {
  @override
  Future<FarmDashboardState> build() async {
    final repository = ref.read(farmRepositoryProvider);
    final farmId = ref.watch(farmContextProvider).farmId;

    if (farmId == null) {
      return FarmDashboardState.initial();
    }

    final summaryFuture =
        repository.getDashboardSummary(farmId: farmId);

    final activitiesFuture =
        repository.getTodayActivities(farmId: farmId);

    final summary = await summaryFuture;
    final activities = await activitiesFuture;

    return FarmDashboardState(
      summary: summary,
      todayActivities: activities,
      isLoading: false,
      errorMessage: null,
      farmId: farmId,
    );
  }

  Future<void> recordProduction(
    ProductionEntity production,
  ) async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId == null) return;

    final repository = ref.read(farmRepositoryProvider);
    await repository.recordProduction(
      farmId: farmId,
      production: production,
    );

    // ── Cross-module workflow: Production → Marketplace ──
    try {
      await repository.syncMarketplaceListing(farmId: farmId);
    } catch (_) {
      // Non-critical
    }

    ref.invalidateSelf();
  }

  Future<void> createActivity(
    ActivityModel activity,
  ) async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId == null) return;

    final repository = ref.read(farmRepositoryProvider);
    await repository.createActivity(
      farmId: farmId,
      activity: activity,
    );

    ref.invalidateSelf();
  }

  Future<void> syncMarketplaceListing() async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId == null) return;

    final repository = ref.read(farmRepositoryProvider);
    await repository.syncMarketplaceListing(
      farmId: farmId,
    );

    ref.invalidateSelf();
  }
}
