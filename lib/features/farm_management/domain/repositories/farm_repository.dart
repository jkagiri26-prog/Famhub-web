import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/asset_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/crop_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/field_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/models/livestock_model.dart';
import 'package:famhub_app/features/farm_management/domain/models/production_model.dart';

/// Backend-ready contract for all farm-management operations.
///
/// Note: This is intentionally *not* coupled to Supabase.
/// Supabase (and RLS) will be handled inside the infrastructure layer.
abstract class FarmRepository {
  // ── Dashboard ──────────────────────────────────────────────
  Future<FarmDashboardSummary> getDashboardSummary({required String farmId});
  Future<List<ActivityModel>> getTodayActivities({required String farmId});
  Future<List<FarmEntity>> getUserFarms();

  // ── Crops ──────────────────────────────────────────────────
  Future<List<CropModel>> getCrops({required String farmId});
  Future<void> createCrop({required String farmId, required CropModel crop});

  // ── Livestock ──────────────────────────────────────────────
  Future<List<LivestockModel>> getLivestock({required String farmId});
  Future<void> createLivestock({required String farmId, required LivestockModel livestock});

  // ── Assets ─────────────────────────────────────────────────
  Future<List<AssetModel>> getAssets({required String farmId});
  Future<void> createAsset({required String farmId, required AssetModel asset});

  // ── Fields ─────────────────────────────────────────────────
  Future<List<FieldModel>> getFields({required String farmId});

  // ── Production ─────────────────────────────────────────────
  Future<List<ProductionModel>> getProductionRecords({required String farmId});
  Future<void> recordProduction({
    required String farmId,
    required ProductionModel production,
  });

  // ── Activities ─────────────────────────────────────────────
  Future<List<ActivityModel>> getActivities({required String farmId});
  Future<void> createActivity({
    required String farmId,
    required ActivityModel activity,
  });

  // ── Cross-Module ───────────────────────────────────────────
  Future<void> syncMarketplaceListing({required String farmId});
}

