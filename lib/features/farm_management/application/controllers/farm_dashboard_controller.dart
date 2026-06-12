import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';
import 'package:famhub_app/features/farm_management/domain/models/production_model.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/production_provider.dart';
import 'package:famhub_app/features/farm_management/application/workflows/production_to_marketplace_workflow.dart';
import 'package:famhub_app/features/farm_management/application/state/farm_dashboard_state.dart';

/// Dashboard controller:
/// - Reads farm context
/// - Loads dashboard data
/// - Executes farm actions
/// - Triggers cross-module workflows
class FarmDashboardController extends AsyncNotifier<FarmDashboardState> {
  late final FarmRepository repository;

  @override
  Future<FarmDashboardState> build() async {
    // Repository should be injected via provider (future improvement),
    // but kept simple here for stability phase.
    repository = ref.read(farmRepositoryProvider);

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
    ProductionModel production,
  ) async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId == null) return;

    await repository.recordProduction(
      farmId: farmId,
      production: production,
    );

    // ── Cross-module workflow: Production → Marketplace ──
    final workflowNotifier = ref.read(crossModuleWorkflowProvider(farmId).notifier);
    await workflowNotifier.onProductionRecorded();

    ref.invalidateSelf();
  }

  Future<void> createActivity(
    ActivityModel activity,
  ) async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId == null) return;

    await repository.createActivity(
      farmId: farmId,
      activity: activity,
    );

    ref.invalidateSelf();
  }

  Future<void> syncMarketplaceListing() async {
    final farmId = ref.read(farmContextProvider).farmId;
    if (farmId == null) return;

    await repository.syncMarketplaceListing(
      farmId: farmId,
    );

    ref.invalidateSelf();
  }
}