import '../models/activity_model.dart';
import '../models/farm_dashboard_summary.dart';
import '../models/farm_entity.dart';
import '../models/production_model.dart';

/// Backend-ready contract for all farm-management operations.
///
/// Note: This is intentionally *not* coupled to Supabase.
/// Supabase (and RLS) will be handled inside the infrastructure layer.
abstract class FarmRepository {
  Future<FarmDashboardSummary> getDashboardSummary({required String farmId});

  Future<List<ActivityModel>> getTodayActivities({required String farmId});

  Future<List<FarmEntity>> getUserFarms();

  Future<void> recordProduction({
    required String farmId,
    required ProductionModel production,
  });

  Future<void> createActivity({
    required String farmId,
    required ActivityModel activity,
  });

  Future<void> syncMarketplaceListing({required String farmId});
}

