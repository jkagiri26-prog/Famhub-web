/// ============================================================
/// DEMO FARM REPOSITORY — Provides realistic sample data for Guest Mode
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   shared/demo/ = reusable demo data repositories
///
/// ✅ Responsibilities:
///   - Implement FarmRepository interface with hardcoded sample data
///   - Provide realistic-looking farm data for demo/guest mode
///   - Never access Supabase
///   - Identical return types as Supabase implementation
///
/// ✅ ARCHITECTURE COMPLIANCE:
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
  // ── Sample Farm IDs ──
  static const String farm1Id = 'demo-farm-001';
  static const String farm1Name = 'Green Valley Farm';

  // ── Sample Data ──
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

  // ── Dashboard ──

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
      notes: 'Morning drip irrigation - Field A - Snow Peas - 30 min',
    ),
    ActivityModel(
      id: 'demo-act-002',
      activityTypeId: 'inspection',
      performedAt: _today.subtract(const Duration(hours: 4)),
      notes: 'Pest scouting - Cabbage section - No significant pests found',
    ),
    ActivityModel(
      id: 'demo-act-003',
      activityTypeId: 'harvesting',
      performedAt: _yesterday.subtract(const Duration(hours: 6)),
      notes: 'Harvested 45kg Snow Peas - Grade A',
    ),
    ActivityModel(
      id: 'demo-act-004',
      activityTypeId: 'fertilizing',
      performedAt: _yesterday.subtract(const Duration(hours: 3)),
      notes: 'Applied DAP fertilizer - Field B - 25kg',
    ),
    ActivityModel(
      id: 'demo-act-005',
      activityTypeId: 'maintenance',
      performedAt: _twoDaysAgo.subtract(const Duration(hours: 4)),
      notes: 'Repaired irrigation line - Section 2 leak',
    ),
    ActivityModel(
      id: 'demo-act-006',
      activityTypeId: 'planting',
      performedAt: _threeDaysAgo.subtract(const Duration(hours: 5)),
      notes: 'Planted 200 cabbage seedlings - Field C',
    ),
    ActivityModel(
      id: 'demo-act-007',
      activityTypeId: 'spraying',
      performedAt: _lastWeek.subtract(const Duration(hours: 3)),
      notes: 'Foliar feed application - Mixed vegetables',
    ),
    ActivityModel(
      id: 'demo-act-008',
      activityTypeId: 'irrigation',
      performedAt: _lastWeek.subtract(const Duration(hours: 6)),
      notes: 'Afternoon irrigation - All fields - 45 min',
    ),
  ];

  @override
  Future<List<FarmEntity>> getUserFarms() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _sampleFarms;
  }

  // ── Crops ──

  @override
  Future<List<CropEntity>> getCrops({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleCrops.where((c) => c.farmId == farmId).toList();
  }

  @override
  Future<void> createCrop({required String farmId, required CropEntity crop}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    // In demo mode, simulate success
  }

  // ── Livestock ──

  @override
  Future<List<LivestockEntity>> getLivestock({required String farmId}) async {
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
  Future<void> createLivestock({required String farmId, required LivestockEntity livestock}) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // ── Assets ──

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
  Future<void> createAsset({required String farmId, required AssetEntity asset}) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // ── Fields ──

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
      status: 'active',
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
      status: 'active',
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
      status: 'active',
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
      status: 'fallow',
      notes: 'Resting, green manure cover',
      createdAt: _twoWeeksAgo,
    ),
  ];

  // ── Production ──

  @override
  Future<List<ProductionEntity>> getProductionRecords({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleProduction
        .where((p) => p.farmId == farmId)
        .map((p) => ProductionEntity(
              id: p.id,
              activityId: p.activityId,
              variantId: p.variantId,
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
    _DemoProductionRecord(
      farmId: farm1Id,
      id: 'demo-prod-001',
      activityId: 'demo-act-003',
      variantId: 'snow-peas',
      quantity: 45.0,
      unitId: 'kg',
      categoryId: 'vegetables',
      assetId: 'demo-asset-001',
      fieldId: 'demo-field-001',
    ),
    _DemoProductionRecord(
      farmId: farm1Id,
      id: 'demo-prod-002',
      activityId: null,
      variantId: 'tomatoes',
      quantity: 120.0,
      unitId: 'kg',
      categoryId: 'vegetables',
      assetId: 'demo-asset-001',
      fieldId: 'demo-field-002',
    ),
    _DemoProductionRecord(
      farmId: farm1Id,
      id: 'demo-prod-003',
      activityId: null,
      variantId: 'eggs',
      quantity: 240.0,
      unitId: 'pieces',
      categoryId: 'poultry',
      assetId: 'demo-ls-002',
      fieldId: null,
    ),
  ];

  @override
  Future<void> recordProduction({required String farmId, required ProductionEntity production}) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // ── Activities ──

  @override
  Future<List<ActivityModel>> getActivities({required String farmId}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _sampleActivities;
  }

  @override
  Future<void> createActivity({required String farmId, required ActivityModel activity}) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  // ── Activity Values ──

  @override
  Future<void> persistActivityValues({
    required String farmId,
    required String activityId,
    required Map<String, dynamic> values,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  // ── Stock ──

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

  // ── Financial ──

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

  // ── KPI ──

  @override
  Future<void> updateProductionKpis({required String farmId, double? quantity}) async {}

  @override
  Future<void> updateFinancialKpis({required String farmId, String? recordType, double? amount}) async {}

  @override
  Future<void> updateStockValueKpi({required String farmId}) async {}

  // ── Cross-Module ──

  @override
  Future<void> syncMarketplaceListing({required String farmId}) async {}
}

/// Helper class to track farmId for production records
class _DemoProductionRecord {
  final String farmId;
  final String id;
  final String? activityId;
  final String? variantId;
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
    required this.quantity,
    this.unitId,
    this.categoryId,
    this.assetId,
    this.fieldId,
  });
}


