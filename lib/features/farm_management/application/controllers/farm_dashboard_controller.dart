import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/activity_model.dart';
import '../../domain/models/farm_dashboard_summary.dart';
import '../../domain/models/production_model.dart';
import '../../domain/repositories/farm_repository.dart';

import '../providers/farm_context_provider.dart';
import '../state/farm_dashboard_state.dart';

/// Dashboard controller:
/// - Reads farm context
/// - Loads dashboard data
/// - Executes farm actions
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