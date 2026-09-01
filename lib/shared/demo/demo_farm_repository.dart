/// ============================================================
/// DEMO FARM REPOSITORY â€” Provides realistic sample data for Guest Mode
/// ============================================================
///
/// ðŸ§  LOCATION CONTEXT:
///   shared/demo/ = reusable demo data repositories
///
/// âœ… Responsibilities:
///   - Implement FarmRepository interface with hardcoded sample data
///   - Provide realistic-looking farm data for demo/guest mode
///   - Never access Supabase
///   - Identical return types as Supabase implementation
///
/// âœ… ARCHITECTURE COMPLIANCE:
///   - Implements the same FarmRepository interface
///   - Widgets don't know whether data comes from demo or Supabase
///   - No guest logic inside widgets
/// ============================================================
library famhub_app.shared.demo.demo_farm_repository;

import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/entities/asset_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/enums/crop_status.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';

/// Demo implementation of FarmRepository.
///
/// Returns hardcoded sample data that looks realistic.
/// Data is consistent across calls (same farm IDs, crop IDs, etc.)
/// so the dashboard appears fully populated and active.
class DemoFarmRepository implements FarmRepository {
  // â”€â”€ Sample Farm IDs â”€â”€
  static const String farm1Id = 'demo-farm-001';
  static const String farm1Name = 'Green Valley Farm';

  // â”€â”€ Sample Data â”€â”€
  static final DateTime _now = DateTime.now();
  static final DateTime _today = DateTime(_now.year, _now.month, _now.day);
  static final DateTime _yesterday = _today.subtract(const Duration(days: 1));
  static final DateTime _twoDaysAgo = _today.subtract(const Duration(days: 2));
  static final DateTime _threeDaysAgo = _today.subtract(const Duration(days: 3));
  static final DateTime _lastWeek = _today.subtract(const Duration(days: 7));
  static final DateTime _twoWeeksAgo = _today.subtract(const Duration(days: 14));

  static const List<FarmEntity> _sampleFarms = [
    FarmEntity(
      id: farm1Id,
      farmName: 'Green Valley Farm',
      description: 'Mixed crop farm specializing in vegetables and legumes',
      size: 2.5,
      isActive: true,
      isVerified: true,
    ),
    FarmEntity(
      id: 'demo-farm-002',
      farmName: 'Sunrise Orchard',
      description: 'Fruit orchard with integrated poultry',
      size: 5.0,
      isActive: true,
      isVerified: true,
    ),
  ];

  static final List<CropEntity> _sampleCrops = [
    CropEntity(
      id: 'demo-crop-001',
      farmId: farm1Id,
      fieldId: 'demo-field-001',
      cropName: 'Snow Peas',
      variety: 'Oregon Sugar Pod II',
      plantingDate: _sampleDate(2024, 9, 15),
      expectedHarvestDate: _sampleDate(2024, 11, 20),
      areaPlanted: 1.0,
      quantityPlanted: 25.0,
      unit: 'kg',
      status: CropStatus.growing,
      notes: 'Trellised, good germination rate',
      createdAt: _sampleDate(2024, 9, 15),
    ),
    CropEntity(
      id: 'demo-crop-002',
      farmId: farm1Id,
      fieldId: 'demo-field-002',
      cropName: 'Tomatoes',
      variety: 'Anna F1 Hybrid',
      plantingDate: _sampleDate(2024, 8, 1),
      expectedHarvestDate: _sampleDate(2024, 10, 15),
      areaPlanted: 0.75,
      quantityPlanted: 500,
      unit: 'seedlings',
      status: CropStatus.harvested,
      notes: 'Drip-irrigated, staked',
      createdAt: _sampleDate(2024, 8, 1),
    ),
    CropEntity(
      id: 'demo-crop-003',
      farmId: farm1Id,
      fieldId: 'demo-field-003',
      cropName: 'Cabbages',
      variety: 'Copenhagen Market',
      plantingDate: _sampleDate(2024, 10, 1),
      expectedHarvestDate: _sampleDate(2024, 12, 10),
      areaPlanted: 0.5,
      quantityPlanted: 800,
      unit: 'seedlings',
      status: CropStatus.growing,
      notes: 'Early stage, good stand',
      createdAt: _sampleDate(2024, 10, 1),
    ),
  ];

  static DateTime _sampleDate(int year, int month, int day) {
    return DateTime(year, month, day);
  }

  // â”€â”€ Farm CRUD â”€â”€

  @override
  Future<FarmEntity?> getFarm({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _sampleFarms.firstWhere((f) => f.id == farmId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<FarmEntity>> getFarms() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleFarms;
  }

  @override
    Future<(FarmEntity farm, FieldEntity field)> createFarmWithDefaultField({
      required FarmEntity farm,
    }) async {
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 1: Simulate farm creation (generate an ID)
      final createdFarm = FarmEntity(
        id: 'demo-farm-${DateTime.now().millisecondsSinceEpoch}',
        farmName: farm.farmName,
        description: farm.description,
        size: farm.size,
        isActive: true,
        isVerified: false,
      );

      // Step 2: Auto-create default "Main Field" that inherits the farm's total area
      final defaultField = FieldEntity(
        id: 'demo-field-${DateTime.now().millisecondsSinceEpoch}',
        farmId: createdFarm.id,
        fieldName: 'Main Field',
        acreage: farm.size ?? 0.0,
        soilType: null,
        currentCrop: null,
        isActive: true,
        notes: 'Auto-created default field',
        createdAt: DateTime.now(),
      );

      return (createdFarm, defaultField);
    }

    @override
    Future<FarmEntity> createFarm({required FarmEntity farm}) async {
      await Future.delayed(const Duration(milliseconds: 200));
      return farm; // Simulated success
    }

  @override
  Future<FarmEntity> updateFarm({required FarmEntity farm}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return farm; // Simulated success
  }

  @override
  Future<void> deleteFarm({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    // Simulated success
  }

  @override
  Future<void> refreshDashboard({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> refreshFarm({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> setCurrentFarm({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<void> clearCurrentFarm() async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // â”€â”€ Dashboard â”€â”€

  @override
  Future<FarmDashboardSummary> getDashboardSummary({required String farmId}) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 200));

    return const FarmDashboardSummary(
      totalProduction: 1250.0,
      totalSales: 89000.0,
      totalExpenses: 34500.0,
      totalYield: 345.0,
      stockValue: 28000.0,
    );
  }

  @override
  Future<List<ActivityModel>> getTodayActivities({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleActivities.where((a) => a.performedAt.isAfter(_today.subtract(const Duration(hours: 24)))).toList();
  }

  static final List<ActivityModel> _sampleActivities = [
    ActivityModel(
      id: 'demo-act-001',
      activityTypeId: 'irrigation',
      performedAt: _today.subtract(const Duration(hours: 2)),
      fieldId: 'demo-field-001',
      cropOrLivestockId: 'demo-crop-001',
      cropOrLivestockType: 'crop',
      notes: 'Morning drip irrigation - Field A - Snow Peas - 30 min',
    ),
    ActivityModel(
      id: 'demo-act-002',
      activityTypeId: 'inspection',
      performedAt: _today.subtract(const Duration(hours: 4)),
      fieldId: 'demo-field-003',
      cropOrLivestockId: 'demo-crop-003',
      cropOrLivestockType: 'crop',
      notes: 'Pest scouting - Cabbage section - No significant pests found',
    ),
    ActivityModel(
      id: 'demo-act-003',
      activityTypeId: 'harvesting',
      performedAt: _yesterday.subtract(const Duration(hours: 6)),
      fieldId: 'demo-field-001',
      cropOrLivestockId: 'demo-crop-001',
      cropOrLivestockType: 'crop',
      notes: 'Harvested 45kg Snow Peas - Grade A',
    ),
    ActivityModel(
      id: 'demo-act-004',
      activityTypeId: 'fertilizing',
      performedAt: _yesterday.subtract(const Duration(hours: 3)),
      fieldId: 'demo-field-002',
      cropOrLivestockId: 'demo-crop-002',
      cropOrLivestockType: 'crop',
      notes: 'Applied DAP fertilizer - Field B - 25kg',
    ),
    ActivityModel(
      id: 'demo-act-005',
      activityTypeId: 'maintenance',
      performedAt: _twoDaysAgo.subtract(const Duration(hours: 4)),
      fieldId: 'demo-field-002',
      cropOrLivestockId: 'demo-crop-002',
      cropOrLivestockType: 'crop',
      notes: 'Repaired irrigation line - Section 2 leak',
    ),
    ActivityModel(
      id: 'demo-act-006',
      activityTypeId: 'planting',
      performedAt: _threeDaysAgo.subtract(const Duration(hours: 5)),
      fieldId: 'demo-field-003',
      cropOrLivestockId: 'demo-crop-003',
      cropOrLivestockType: 'crop',
      notes: 'Planted 200 cabbage seedlings - Field C',
    ),
    ActivityModel(
      id: 'demo-act-007',
      activityTypeId: 'spraying',
      performedAt: _lastWeek.subtract(const Duration(hours: 3)),
      fieldId: 'demo-field-001',
      cropOrLivestockId: 'demo-crop-001',
      cropOrLivestockType: 'crop',
      notes: 'Foliar feed application - Mixed vegetables',
    ),
    ActivityModel(
      id: 'demo-act-008',
      activityTypeId: 'irrigation',
      performedAt: _lastWeek.subtract(const Duration(hours: 6)),
      fieldId: 'demo-field-001',
      cropOrLivestockId: 'demo-crop-001',
      cropOrLivestockType: 'crop',
      notes: 'Afternoon irrigation - All fields - 45 min',
    ),
  ];

  @override
  Future<List<FarmEntity>> getUserFarms() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _sampleFarms;
  }

  // â”€â”€ Crops â”€â”€

  @override
  Future<List<CropEntity>> getCrops({required String farmId, String? fieldId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleCrops.where((c) => c.farmId == farmId).toList();
  }

  @override
    Future<CropEntity> createCrop({required String farmId, required CropEntity crop}) async {
      await Future.delayed(const Duration(milliseconds: 100));
      return crop; // Simulated success
    }

  // â”€â”€ Livestock â”€â”€

  @override
  Future<List<LivestockEntity>> getLivestock({required String farmId, String? fieldId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleLivestock.where((l) => l.farmId == farmId).toList();
  }

  static final List<LivestockEntity> _sampleLivestock = [
    LivestockEntity(
      id: 'demo-ls-001',
      farmId: farm1Id,
      species: 'Goats',
      breed: 'Saanen',
      count: 12,
      healthStatus: 'Healthy',
      purpose: 'Milk & Breeding',
      notes: 'All vaccinated, dewormed monthly',
      createdAt: _twoWeeksAgo,
    ),
    LivestockEntity(
      id: 'demo-ls-002',
      farmId: farm1Id,
      species: 'Chickens',
      breed: 'Kuroiler',
      count: 45,
      healthStatus: 'Healthy',
      purpose: 'Eggs & Meat',
      notes: 'Laying 30+ eggs/day',
      createdAt: _twoWeeksAgo,
    ),
  ];

  @override
    Future<LivestockEntity> createLivestock({required String farmId, required LivestockEntity livestock}) async {
      await Future.delayed(const Duration(milliseconds: 100));
      return livestock; // Simulated success
    }

  // â”€â”€ Assets â”€â”€

  @override
  Future<List<AssetEntity>> getAssets({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleAssets.where((a) => a.farmId == farmId).toList();
  }

  static final List<AssetEntity> _sampleAssets = [
    AssetEntity(
      id: 'demo-asset-001',
      farmId: farm1Id,
      assetName: 'Knapsack Sprayer',
      assetType: 'Equipment',
      manufacturer: 'Matabi',
      model: 'Super 16L',
      yearPurchased: 2023,
      condition: 'Good',
      lastMaintenanceDate: _lastWeek,
      notes: 'Cleaned after each use',
      isActive: true,
      createdAt: _twoWeeksAgo,
    ),
    AssetEntity(
      id: 'demo-asset-002',
      farmId: farm1Id,
      assetName: 'Water Pump',
      assetType: 'Machinery',
      manufacturer: 'Pedrollo',
      model: 'PKm 60',
      yearPurchased: 2022,
      condition: 'Excellent',
      lastMaintenanceDate: _twoWeeksAgo,
      notes: 'Serves all irrigation lines',
      isActive: true,
      createdAt: _twoWeeksAgo,
    ),
    AssetEntity(
      id: 'demo-asset-003',
      farmId: farm1Id,
      assetName: 'Storage Shed',
      assetType: 'Structure',
      manufacturer: null,
      model: null,
      yearPurchased: 2021,
      condition: 'Good',
      notes: 'Tools & harvested produce storage',
      isActive: true,
      createdAt: _twoWeeksAgo,
    ),
  ];

  @override
    Future<AssetEntity> createAsset({required String farmId, required AssetEntity asset}) async {
      await Future.delayed(const Duration(milliseconds: 100));
      return asset; // Simulated success
    }

  // â”€â”€ Fields â”€â”€

  @override
  Future<List<FieldEntity>> getFields({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleFields.where((f) => f.farmId == farmId).toList();
  }

  static final List<FieldEntity> _sampleFields = [
    FieldEntity(
      id: 'demo-field-001',
      farmId: farm1Id,
      fieldName: 'Field A - Snow Peas',
      acreage: 1.0,
      soilType: 'Loamy',
      currentCrop: 'Snow Peas',
      isActive: true,
      notes: 'Trellised, drip irrigated',
      createdAt: _twoWeeksAgo,
    ),
    FieldEntity(
      id: 'demo-field-002',
      farmId: farm1Id,
      fieldName: 'Field B - Tomatoes',
      acreage: 0.75,
      soilType: 'Sandy Loam',
      currentCrop: 'Tomatoes',
      isActive: true,
      notes: 'Staked, drip irrigated',
      createdAt: _twoWeeksAgo,
    ),
    FieldEntity(
      id: 'demo-field-003',
      farmId: farm1Id,
      fieldName: 'Field C - Cabbages',
      acreage: 0.5,
      soilType: 'Clay Loam',
      currentCrop: 'Cabbages',
      isActive: true,
      notes: 'Newly planted',
      createdAt: _twoWeeksAgo,
    ),
    FieldEntity(
      id: 'demo-field-004',
      farmId: farm1Id,
      fieldName: 'Fallow Plot',
      acreage: 0.25,
      soilType: 'Loamy',
      currentCrop: null,
      isActive: false,
      notes: 'Resting, green manure cover',
      createdAt: _twoWeeksAgo,
    ),
  ];

  // â”€â”€ Production â”€â”€

  @override
  Future<List<ProductionEntity>> getProductionRecords({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleProduction
        .where((p) => p.farmId == farmId)
        .map((p) => ProductionEntity(
              id: p.id,
              activityId: p.activityId,
              variantId: p.variantId,
              outputCommodityId: p.outputCommodityId,
              quantity: p.quantity,
              unitId: p.unitId,
              categoryId: p.categoryId,
              assetId: p.assetId,
              fieldId: p.fieldId,
            ))
        .toList();
  }

  // Production records are associated with farm via assetId in this demo
  static final List<_DemoProductionRecord> _sampleProduction = [
    const _DemoProductionRecord(
      farmId: farm1Id,
      id: 'demo-prod-001',
      activityId: 'demo-act-003',
      variantId: 'snow-peas',
      outputCommodityId: 'demo-commodity-crops-003',
      quantity: 45.0,
      unitId: 'demo-unit-kg',
      categoryId: 'vegetables',
      assetId: 'demo-asset-001',
      fieldId: 'demo-field-001',
    ),
    const _DemoProductionRecord(
      farmId: farm1Id,
      id: 'demo-prod-002',
      activityId: null,
      variantId: 'tomatoes',
      outputCommodityId: 'demo-commodity-crops-002',
      quantity: 120.0,
      unitId: 'demo-unit-kg',
      categoryId: 'vegetables',
      assetId: 'demo-asset-001',
      fieldId: 'demo-field-002',
    ),
    const _DemoProductionRecord(
      farmId: farm1Id,
      id: 'demo-prod-003',
      activityId: null,
      variantId: 'eggs',
      outputCommodityId: 'demo-commodity-poultry-001',
      quantity: 240.0,
      unitId: 'demo-unit-piece',
      categoryId: 'poultry',
      assetId: 'demo-ls-002',
      fieldId: null,
    ),
  ];

  @override
    Future<ProductionEntity> recordProduction({required String farmId, required ProductionEntity production}) async {
      await Future.delayed(const Duration(milliseconds: 100));
      return production; // Simulated success
    }

  // ── Reference Data (Taxonomy) ──

  @override
  Future<List<({String id, String name, String category})>> getCommodities() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return const [
      (id: 'demo-commodity-crops-001', name: 'Maize', category: 'Crops'),
      (id: 'demo-commodity-crops-002', name: 'Tomatoes', category: 'Crops'),
      (id: 'demo-commodity-crops-003', name: 'Snow Peas', category: 'Crops'),
      (id: 'demo-commodity-livestock-001', name: 'Beef', category: 'Livestock'),
      (id: 'demo-commodity-dairy-001', name: 'Milk', category: 'Dairy'),
      (id: 'demo-commodity-poultry-001', name: 'Eggs', category: 'Poultry'),
      (id: 'demo-commodity-fish-001', name: 'Tilapia', category: 'Fish'),
      (id: 'demo-commodity-honey-001', name: 'Honey', category: 'Honey'),
    ];
  }

  @override
  Future<List<({String id, String name})>> getUnits() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return const [
      (id: 'demo-unit-kg', name: 'Kilogram (kg)'),
      (id: 'demo-unit-ton', name: 'Tonne'),
      (id: 'demo-unit-litre', name: 'Litre'),
      (id: 'demo-unit-piece', name: 'Piece'),
      (id: 'demo-unit-crate', name: 'Crate'),
      (id: 'demo-unit-bag', name: 'Bag'),
      (id: 'demo-unit-dozen', name: 'Dozen'),
      (id: 'demo-unit-head', name: 'Head'),
    ];
  }

  // â”€â”€ Activities â”€â”€

  @override
    Future<List<ActivityModel>> getActivities({required String farmId}) async {
      await Future.delayed(const Duration(milliseconds: 150));
      return _sampleActivities;
    }

    @override
    Future<ActivityModel> createActivity({required ActivityModel activity}) async {
      await Future.delayed(const Duration(milliseconds: 100));
      return activity; // Simulated success
    }

  // â”€â”€ Activity Values â”€â”€

  @override
  Future<void> persistActivityValues({
    required String farmId,
    required String activityId,
    required Map<String, dynamic> values,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // â”€â”€ Stock â”€â”€

  @override
  Future<Map<String, dynamic>> consumeStock({
    required String farmId,
    required String assetId,
    required double quantity,
    String? activityId,
    String? unitId,
    String? description,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {'success': true, 'new_balance': 100 - quantity, 'quantity': -quantity};
  }

  @override
  Future<Map<String, dynamic>> addStock({
    required String farmId,
    required String assetId,
    required double quantity,
    String? activityId,
    String? unitId,
    String? description,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {'success': true, 'new_balance': 100 + quantity, 'quantity': quantity};
  }

  @override
  Future<Map<String, double>> getAvailableStock({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return {
      'demo-asset-001': 85.0,
      'demo-asset-002': 12.0,
    };
  }

  // â”€â”€ Financial â”€â”€

  @override
  Future<void> recordFinancialTransaction({
    required String farmId,
    required String recordType,
    required double amount,
    required String description,
    String? activityId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // â”€â”€ KPI â”€â”€

  @override
  Future<void> updateProductionKpis({required String farmId, double? quantity}) async {}

  @override
  Future<void> updateFinancialKpis({required String farmId, String? recordType, double? amount}) async {}

  @override
  Future<void> updateStockValueKpi({required String farmId}) async {}

  // â”€â”€ Cross-Module â”€â”€

  @override
  Future<void> syncMarketplaceListing({required String farmId}) async {}

  // ── Field creation ──

  @override
    Future<FieldEntity> createField({required String farmId, required FieldEntity field}) async {
      await Future.delayed(const Duration(milliseconds: 100));
      return field; // Simulated success
    }

  // ── Crops (continued) ──

  @override
  Future<List<CropEntity>> getCropsByField({required String farmId, required String fieldId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleCrops.where((c) => c.farmId == farmId && c.fieldId == fieldId).toList();
  }

  @override
  Future<CropEntity?> getCropById({required String farmId, required String cropId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _sampleCrops.firstWhere((c) => c.id == cropId);
    } catch (_) {
      return null;
    }
  }

  // ── Livestock (continued) ──

  @override
  Future<List<LivestockEntity>> getLivestockByField({required String farmId, required String fieldId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleLivestock.where((l) => l.farmId == farmId).toList();
  }

  @override
  Future<LivestockEntity?> getLivestockById({required String farmId, required String livestockId}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _sampleLivestock.firstWhere((l) => l.id == livestockId);
    } catch (_) {
      return null;
    }
  }

  // ── Reports ──

  @override
    Future<Map<String, dynamic>> getActivityReport({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {
      'total_activities': _sampleActivities.length,
      'by_type': {
        'irrigation': 2,
        'inspection': 1,
        'harvesting': 1,
        'fertilizing': 1,
        'maintenance': 1,
        'planting': 1,
        'spraying': 1,
      },
    };
  }

  @override
    Future<Map<String, dynamic>> getProductionReport({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {
      'total_production': 1250.0,
      'by_category': {
        'vegetables': 1010.0,
        'poultry': 240.0,
      },
    };
  }
}

/// Helper class to track farmId for production records
class _DemoProductionRecord {
  final String farmId;
  final String id;
  final String? activityId;
  final String? variantId;
  final String? outputCommodityId;
  final double quantity;
  final String? unitId;
  final String? categoryId;
  final String? assetId;
  final String? fieldId;

  const _DemoProductionRecord({
    required this.farmId,
    required this.id,
    this.activityId,
    this.variantId,
    this.outputCommodityId,
    required this.quantity,
    this.unitId,
    this.categoryId,
    this.assetId,
    this.fieldId,
  });
}




