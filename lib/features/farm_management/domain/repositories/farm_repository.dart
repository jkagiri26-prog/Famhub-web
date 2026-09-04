import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/entities/asset_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';

/// Backend-ready contract for all farm-management operations.
///
/// 🏗️ OFFICIAL HIERARCHY:
///   Farm / Entity → Field / Block → **Crop or Livestock** → **Activity** → **Report**
///
/// Note: This is intentionally *not* coupled to Supabase.
/// Supabase (and RLS) will be handled inside the infrastructure layer.
abstract class FarmRepository {
  // ── Farm CRUD ──────────────────────────────────────────────
  /// Get a single farm by ID
  Future<FarmEntity?> getFarm({required String farmId});

  /// Get all farms for the current user
  Future<List<FarmEntity>> getFarms();

  /// Create a new farm
  Future<FarmEntity> createFarm({required FarmEntity farm});

  /// Create a new farm AND automatically create a default "Main Field"
  /// that inherits the farm's total area.
  ///
  /// Returns a record containing the created farm and the auto-created field.
  Future<(FarmEntity farm, FieldEntity field)> createFarmWithDefaultField({
    required FarmEntity farm,
  });

  /// Update an existing farm
  Future<FarmEntity> updateFarm({required FarmEntity farm});

  /// Delete a farm
  Future<void> deleteFarm({required String farmId});

  // ── Dashboard ──────────────────────────────────────────────
  Future<FarmDashboardSummary> getDashboardSummary({required String farmId});
  Future<List<ActivityModel>> getTodayActivities({required String farmId});
  Future<List<FarmEntity>> getUserFarms();

  // ── Dashboard Refresh ──────────────────────────────────────
  Future<void> refreshDashboard({required String farmId});
  Future<void> refreshFarm({required String farmId});
  Future<void> setCurrentFarm({required String farmId});
  Future<void> clearCurrentFarm();

  // ── Fields / Blocks ────────────────────────────────────────
  Future<List<FieldEntity>> getFields({required String farmId});

  /// Create a new field/block. Returns the field with backend-generated ID.
  Future<FieldEntity> createField({required String farmId, required FieldEntity field});

  // ── Crops ──────────────────────────────────────────────────
  Future<List<CropEntity>> getCrops({
    required String farmId,
    String? fieldId,
  });

  Future<List<CropEntity>> getCropsByField({
    required String farmId,
    required String fieldId,
  });

  /// Create a crop. Returns the crop with backend-generated ID.
  Future<CropEntity> createCrop({required String farmId, required CropEntity crop});

  // ── Livestock ──────────────────────────────────────────────
  Future<List<LivestockEntity>> getLivestock({
    required String farmId,
    String? fieldId,
  });

  Future<List<LivestockEntity>> getLivestockByField({
    required String farmId,
    required String fieldId,
  });

  /// Create livestock. Returns the livestock with backend-generated ID.
  Future<LivestockEntity> createLivestock({required String farmId, required LivestockEntity livestock});

  // ── Assets ─────────────────────────────────────────────────
  Future<List<AssetEntity>> getAssets({required String farmId});

  /// Create an asset. Returns the asset with backend-generated ID.
  Future<AssetEntity> createAsset({required String farmId, required AssetEntity asset});

  // ── Production ─────────────────────────────────────────────
  Future<List<ProductionEntity>> getProductionRecords({required String farmId});

  /// Record production. Returns the production record with backend-generated ID.
  ///
  /// The backend `trg_sync_production_to_stock` trigger requires
  /// `output_commodity_id` (→ core.commodities.id) and a positive
  /// `quantity`; `entity_id` is derived server-side via
  /// `core.auth_user_id()`. `unit_id` / `field_id` / `asset_id` /
  /// `activity_id` are optional context.
  Future<ProductionEntity> recordProduction({
    required String farmId,
    required ProductionEntity production,
  });

  // ── Reference Data (Taxonomy) ──────────────────────────────
  /// Active commodities from `core.commodities`.
  /// Returns id, name and category for each commodity.
  Future<List<({String id, String name, String category})>> getCommodities();

  /// Units from `core.units`.
  /// Returns id and name for each unit.
  Future<List<({String id, String name})>> getUnits();

  /// Crop/livestock variants from `core.item_variants` (joined with their
  /// parent `core.items` name). Returns id, itemName, variantName.
  Future<List<({String id, String itemName, String variantName})>> getVariants();

  /// Categories for the requested asset domain, using the authoritative
  /// `core.categories -> core.domains` relationship.
  Future<List<({String id, String name})>> getCategoriesForAssetType({
    required String assetType,
  });

  /// Items for a specific category, constrained by the existing
  /// `core.categories -> core.items` relationship.
  Future<List<({String id, String categoryId, String name})>> getItemsForCategory({
    required String categoryId,
  });

  /// Variants for a specific item, constrained by the existing
  /// `core.items -> core.item_variants` relationship.
  Future<List<({String id, String itemName, String variantName})>> getVariantsForItem({
    required String itemId,
  });

  // ── Activities ─────────────────────────────────────────────
  /// Get activities for a farm. UI filtering by hierarchy is client-side.
  Future<List<ActivityModel>> getActivities({required String farmId});

  /// Map of activity_types id → display name (global catalog).
  Future<Map<String, String>> getActivityTypeNames();

  /// Create an activity. Returns the activity with backend-generated ID.
  /// Only columns documented in farm_management.activities are inserted.
  Future<ActivityModel> createActivity({required ActivityModel activity});

  // ── Activity Attribute Values ──────────────────────────────
  Future<void> persistActivityValues({
    required String farmId,
    required String activityId,
    required Map<String, dynamic> values,
  });

  // ── Crop / Livestock Detail ────────────────────────────────
  Future<CropEntity?> getCropById({
    required String farmId,
    required String cropId,
  });

  Future<LivestockEntity?> getLivestockById({
    required String farmId,
    required String livestockId,
  });

  // ── Report Aggregations ────────────────────────────────────
  /// Get activity summary for a farm. UI filtering by hierarchy is client-side.
  Future<Map<String, dynamic>> getActivityReport({required String farmId});

  /// Get production summary for a farm. UI filtering by hierarchy is client-side.
  Future<Map<String, dynamic>> getProductionReport({required String farmId});

  // ── Inventory / Stock ──────────────────────────────────────
  Future<Map<String, dynamic>> consumeStock({
    required String farmId,
    required String assetId,
    required double quantity,
    String? activityId,
    String? unitId,
    String? description,
  });

  Future<Map<String, dynamic>> addStock({
    required String farmId,
    required String assetId,
    required double quantity,
    String? activityId,
    String? unitId,
    String? description,
  });

  Future<Map<String, double>> getAvailableStock({required String farmId});

  // ── Financial Records ──────────────────────────────────────
  Future<void> recordFinancialTransaction({
    required String farmId,
    required String recordType,
    required double amount,
    required String description,
    String? activityId,
  });

  // ── KPI Automation ─────────────────────────────────────────
  Future<void> updateProductionKpis({required String farmId, double? quantity});
  Future<void> updateFinancialKpis({required String farmId, String? recordType, double? amount});
  Future<void> updateStockValueKpi({required String farmId});

  // ── Cross-Module ───────────────────────────────────────────
  Future<void> syncMarketplaceListing({required String farmId});
}