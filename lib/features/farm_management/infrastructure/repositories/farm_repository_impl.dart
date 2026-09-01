import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/mappers/activity_persistence_mapper.dart';
import 'package:famhub_app/features/farm_management/domain/entities/asset_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/farm_management/domain/enums/crop_status.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/domain/services/area_validation_service.dart';
import 'package:famhub_app/features/farm_management/infrastructure/services/kpi_automation_service.dart';

/// Supabase-backed implementation of FarmRepository.
class FarmRepositoryImpl implements FarmRepository {
  final SupabaseClient _client;
  final KpiAutomationService _kpiService;

  FarmRepositoryImpl({
    SupabaseClient? client,
    KpiAutomationService? kpiService,
  })  : _client = client ?? Supabase.instance.client,
        _kpiService = kpiService ?? KpiAutomationService(client: client ?? Supabase.instance.client);

  // ── Farm CRUD ──

  @override
  Future<FarmEntity?> getFarm({required String farmId}) async {
    try {
      final response = await _client
          .schema('farm_management').from('farms')
          .select()
          .eq('id', farmId)
          .maybeSingle();
      if (response == null) return null;
      return _mapFarmRow(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to load farm: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load farm: $e');
    }
  }

  @override
  Future<List<FarmEntity>> getFarms() async {
    return getUserFarms();
  }

  @override
  Future<(FarmEntity farm, FieldEntity field)> createFarmWithDefaultField({
    required FarmEntity farm,
  }) async {
    final createdFarm = await createFarm(farm: farm);
    final farmId = createdFarm.id;
    final farmSize = createdFarm.size ?? 0.0;

    final defaultField = FieldEntity(
      id: '',
      farmId: farmId,
      fieldName: 'Main Field',
      acreage: farmSize,
      soilType: null,
      currentCrop: null,
      notes: 'Auto-created default field',
      createdAt: DateTime.now(),
    );

    // createField now returns the field with backend-generated ID
    final createdField = await createField(farmId: farmId, field: defaultField);

    return (createdFarm, createdField);
  }

  @override
  Future<FarmEntity> createFarm({required FarmEntity farm}) async {
    try {
      // farm_management.farms declares county_id / sub_county_id / ward_id
      // as NOT NULL (FK → core.locations). We must provide REAL location
      // IDs — never fabricate them. If the user's profile has no location
      // levels selected, fail honestly instead of triggering a NOT NULL
      // violation or writing garbage.
      final countyId = farm.countyId;
      final subCountyId = farm.subCountyId;
      final wardId = farm.wardId;
      if (countyId == null || subCountyId == null || wardId == null) {
        throw Exception(
          'Farm location is incomplete. Complete your profile location '
          '(County, Sub-County, Ward) before creating a farm.',
        );
      }

      final response = await _client
          .schema('farm_management').from('farms')
          .insert({
            'farm_name': farm.farmName,
            'description': farm.description,
            'size': farm.size,
            'county_id': countyId,
            'sub_county_id': subCountyId,
            'ward_id': wardId,
            'is_active': farm.isActive,
            'is_verified': farm.isVerified,
          })
          .select()
          .single();
      return _mapFarmRow(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create farm: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create farm: $e');
    }
  }

  @override
  Future<FarmEntity> updateFarm({required FarmEntity farm}) async {
    try {
      final response = await _client
          .schema('farm_management').from('farms')
          .update({
            'farm_name': farm.farmName,
            'description': farm.description,
            'size': farm.size,
            'is_active': farm.isActive,
            'is_verified': farm.isVerified,
          })
          .eq('id', farm.id)
          .select()
          .single();
      return _mapFarmRow(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update farm: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update farm: $e');
    }
  }

  @override
  Future<void> deleteFarm({required String farmId}) async {
    try {
      await _client.schema('farm_management').from('farms').update({'is_active': false}).eq('id', farmId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete farm: ${e.message}');
    } catch (e) {
      throw Exception('Failed to delete farm: $e');
    }
  }

  @override
  Future<void> refreshDashboard({required String farmId}) async {
    try {
      await _client.schema('farm_management').from('farm_kpis').select('id').eq('farm_id', farmId).maybeSingle();
    } catch (_) {
      // Non-critical
    }
  }

  @override
  Future<void> refreshFarm({required String farmId}) async {
    try {
      await _client.schema('farm_management').from('farms').select('id').eq('id', farmId).maybeSingle();
    } catch (_) {
      // Non-critical
    }
  }

  @override
  Future<void> setCurrentFarm({required String farmId}) async {
    // Handled by farmSelectorProvider — this is a lifecycle hook
  }

  @override
  Future<void> clearCurrentFarm() async {
    // Handled by farmSelectorProvider — this is a lifecycle hook
  }

  // ── Dashboard ──

  @override
  Future<FarmDashboardSummary> getDashboardSummary({required String farmId}) async {
    try {
      final response = await _client
          .schema('farm_management').from('farm_kpis')
          .select()
          .eq('farm_id', farmId)
          .single();
      return FarmDashboardSummary(
        totalProduction: (response['total_production'] as num?)?.toDouble() ?? 0.0,
        totalSales: (response['total_sales'] as num?)?.toDouble() ?? 0.0,
        totalExpenses: (response['total_expense'] as num?)?.toDouble() ?? 0.0,
        totalYield: (response['total_yield'] as num?)?.toDouble() ?? 0.0,
        stockValue: (response['stock_value'] as num?)?.toDouble() ?? 0.0,
      );
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') return const FarmDashboardSummary(totalProduction: 0, totalSales: 0, totalExpenses: 0, totalYield: 0, stockValue: 0);
      throw Exception('Failed to load dashboard summary: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load dashboard summary: $e');
    }
  }

  @override
  Future<List<ActivityModel>> getTodayActivities({required String farmId}) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final response = await _queryFarmActivities(
        farmId: farmId,
        extraFilter: (query) => query.gte(
            'performed_at', startOfDay.toIso8601String()),
        limit: 50,
      );
      return response;
    } on PostgrestException catch (e) {
      throw Exception('Failed to load today activities: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load today activities: $e');
    }
  }

  @override
  Future<List<FarmEntity>> getUserFarms() async {
    try {
      final response = await _client
          .schema('farm_management').from('farms')
          .select()
          .eq('is_active', true)
          .order('farm_name', ascending: true);
      return (response as List)
          .cast<Map<String, dynamic>>()
          .map(_mapFarmRow)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load user farms: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load user farms: $e');
    }
  }

  // ── Fields ──

  @override
  Future<List<FieldEntity>> getFields({required String farmId}) async {
    try {
      final response = await _client
          .schema('farm_management').from('fields')
          .select()
          .eq('farm_id', farmId)
          .order('name', ascending: true);
      return (response as List)
          .cast<Map<String, dynamic>>()
          .map(_mapFieldRow)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load fields: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load fields: $e');
    }
  }

  @override
  Future<FieldEntity> createField({required String farmId, required FieldEntity field}) async {
    try {
      final response = await _client
          .schema('farm_management').from('fields')
          .insert({
            'farm_id': farmId,
            'name': field.fieldName,
            'description': field.notes,
            'size': field.acreage,
            'field_type': field.type,
            'soil_type': field.soilType,
            'is_active': field.isActive,
            'unit_id': field.unitId,
          })
          .select()
          .single();
      return _mapFieldRow(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create field: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create field: $e');
    }
  }

  // ── Crops (Hierarchy-Aware) ──

  @override
  Future<List<CropEntity>> getCrops({
    required String farmId,
    String? fieldId,
  }) async {
    try {
      var query = _client.schema('farm_management').from('crops').select().eq('farm_id', farmId);
      if (fieldId != null) {
        query = query.eq('field_id', fieldId);
      }
      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .cast<Map<String, dynamic>>()
          .map((row) => CropEntity(
                id: row['id'] as String,
                farmId: row['farm_id'] as String,
                fieldId: row['field_id'] as String?,
                cropName: row['crop_name'] as String,
                variety: row['variety'] as String?,
                plantingDate: DateTime.parse(row['planting_date'] as String),
                expectedHarvestDate: row['expected_harvest_date'] != null
                    ? DateTime.parse(row['expected_harvest_date'] as String)
                    : null,
                areaPlanted: (row['area_planted'] as num?)?.toDouble(),
                quantityPlanted: (row['quantity_planted'] as num?)?.toDouble(),
                unit: row['unit'] as String?,
                status: _parseCropStatus(row['status'] as String?),
                notes: row['notes'] as String?,
                createdAt: DateTime.parse(row['created_at'] as String),
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load crops: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load crops: $e');
    }
  }

  @override
  Future<List<CropEntity>> getCropsByField({
    required String farmId,
    required String fieldId,
  }) async {
    return getCrops(farmId: farmId, fieldId: fieldId);
  }

  @override
  Future<CropEntity> createCrop({required String farmId, required CropEntity crop}) async {
    try {
      final response = await _client
          .schema('farm_management').from('crops')
          .insert({
            'farm_id': farmId,
            'field_id': crop.fieldId,
            'crop_name': crop.cropName,
            'variety': crop.variety,
            'planting_date': crop.plantingDate.toIso8601String(),
            'expected_harvest_date': crop.expectedHarvestDate?.toIso8601String(),
            'area_planted': crop.areaPlanted,
            'quantity_planted': crop.quantityPlanted,
            'unit': crop.unit,
            'status': crop.status.name,
            'notes': crop.notes,
          })
          .select()
          .single();
      return CropEntity(
        id: response['id'] as String,
        farmId: response['farm_id'] as String,
        fieldId: response['field_id'] as String?,
        cropName: response['crop_name'] as String,
        variety: response['variety'] as String?,
        plantingDate: DateTime.parse(response['planting_date'] as String),
        expectedHarvestDate: response['expected_harvest_date'] != null
            ? DateTime.parse(response['expected_harvest_date'] as String)
            : null,
        areaPlanted: (response['area_planted'] as num?)?.toDouble(),
        quantityPlanted: (response['quantity_planted'] as num?)?.toDouble(),
        unit: response['unit'] as String?,
        status: _parseCropStatus(response['status'] as String?),
        notes: response['notes'] as String?,
        createdAt: DateTime.parse(response['created_at'] as String),
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to create crop: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create crop: $e');
    }
  }

  CropStatus _parseCropStatus(String? status) {
    switch (status) {
      case 'growing':
        return CropStatus.growing;
      case 'harvested':
        return CropStatus.harvested;
      case 'failed':
        return CropStatus.failed;
      default:
        return CropStatus.planted;
    }
  }

  // ── Livestock (Hierarchy-Aware) ──

  @override
  Future<List<LivestockEntity>> getLivestock({
    required String farmId,
    String? fieldId,
  }) async {
    try {
      var query = _client.schema('farm_management').from('livestock').select().eq('farm_id', farmId);
      if (fieldId != null) {
        query = query.eq('field_id', fieldId);
      }
      final response = await query.order('created_at', ascending: false);
      return (response as List)
          .cast<Map<String, dynamic>>()
          .map((row) => LivestockEntity(
                id: row['id'] as String,
                farmId: row['farm_id'] as String,
                species: row['species'] as String,
                breed: row['breed'] as String?,
                count: row['count'] as int,
                dateOfBirth: row['date_of_birth'] != null
                    ? DateTime.parse(row['date_of_birth'] as String)
                    : null,
                healthStatus: row['health_status'] as String?,
                purpose: row['purpose'] as String?,
                notes: row['notes'] as String?,
                createdAt: DateTime.parse(row['created_at'] as String),
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load livestock: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load livestock: $e');
    }
  }

  @override
  Future<List<LivestockEntity>> getLivestockByField({
    required String farmId,
    required String fieldId,
  }) async {
    try {
      final response = await _client
          .schema('farm_management').from('livestock')
          .select()
          .eq('farm_id', farmId)
          .eq('field_id', fieldId)
          .order('created_at', ascending: false);
      return (response as List)
          .cast<Map<String, dynamic>>()
          .map((row) => LivestockEntity(
                id: row['id'] as String,
                farmId: row['farm_id'] as String,
                species: row['species'] as String,
                breed: row['breed'] as String?,
                count: row['count'] as int,
                dateOfBirth: row['date_of_birth'] != null
                    ? DateTime.parse(row['date_of_birth'] as String)
                    : null,
                healthStatus: row['health_status'] as String?,
                purpose: row['purpose'] as String?,
                notes: row['notes'] as String?,
                createdAt: DateTime.parse(row['created_at'] as String),
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load livestock by field: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load livestock by field: $e');
    }
  }

  @override
  Future<LivestockEntity?> getLivestockById({
    required String farmId,
    required String livestockId,
  }) async {
    try {
      final response = await _client
          .schema('farm_management').from('livestock')
          .select()
          .eq('id', livestockId)
          .eq('farm_id', farmId)
          .maybeSingle();
      if (response == null) return null;
      final row = response;
      return LivestockEntity(
        id: row['id'] as String,
        farmId: row['farm_id'] as String,
        species: row['species'] as String,
        breed: row['breed'] as String?,
        count: row['count'] as int,
        dateOfBirth: row['date_of_birth'] != null
            ? DateTime.parse(row['date_of_birth'] as String)
            : null,
        healthStatus: row['health_status'] as String?,
        purpose: row['purpose'] as String?,
        notes: row['notes'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to load livestock: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load livestock: $e');
    }
  }

  @override
  Future<LivestockEntity> createLivestock({
    required String farmId,
    required LivestockEntity livestock,
  }) async {
    try {
      final response = await _client
          .schema('farm_management').from('livestock')
          .insert({
            'farm_id': farmId,
            'species': livestock.species,
            'breed': livestock.breed,
            'count': livestock.count,
            'date_of_birth': livestock.dateOfBirth?.toIso8601String(),
            'health_status': livestock.healthStatus,
            'purpose': livestock.purpose,
            'notes': livestock.notes,
          })
          .select()
          .single();
      return LivestockEntity(
        id: response['id'] as String,
        farmId: response['farm_id'] as String,
        species: response['species'] as String,
        breed: response['breed'] as String?,
        count: response['count'] as int,
        dateOfBirth: response['date_of_birth'] != null
            ? DateTime.parse(response['date_of_birth'] as String)
            : null,
        healthStatus: response['health_status'] as String?,
        purpose: response['purpose'] as String?,
        notes: response['notes'] as String?,
        createdAt: DateTime.parse(response['created_at'] as String),
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to create livestock: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create livestock: $e');
    }
  }

  // ── Assets ──

  @override
  Future<List<AssetEntity>> getAssets({required String farmId}) async {
    try {
      final response = await _client
          .schema('farm_management').from('assets')
          .select()
          .eq('farm_id', farmId)
          .order('created_at', ascending: false);
      return (response as List)
          .cast<Map<String, dynamic>>()
          .map((row) => AssetEntity(
                id: row['id'] as String,
                farmId: row['farm_id'] as String,
                assetName: row['asset_name'] as String,
                assetType: row['asset_type'] as String,
                manufacturer: row['manufacturer'] as String?,
                model: row['model'] as String?,
                yearPurchased: row['year_purchased'] as int?,
                condition: row['condition'] as String?,
                lastMaintenanceDate: row['last_maintenance_date'] != null
                    ? DateTime.parse(row['last_maintenance_date'] as String)
                    : null,
                notes: row['notes'] as String?,
                isActive: row['is_active'] as bool? ?? true,
                createdAt: DateTime.parse(row['created_at'] as String),
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load assets: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load assets: $e');
    }
  }

  @override
  Future<AssetEntity> createAsset({
    required String farmId,
    required AssetEntity asset,
  }) async {
    try {
      final response = await _client
          .schema('farm_management').from('assets')
          .insert({
            'farm_id': farmId,
            'asset_name': asset.assetName,
            'asset_type': asset.assetType,
            'manufacturer': asset.manufacturer,
            'model': asset.model,
            'year_purchased': asset.yearPurchased,
            'condition': asset.condition,
            'last_maintenance_date': asset.lastMaintenanceDate?.toIso8601String(),
            'notes': asset.notes,
            'is_active': asset.isActive,
          })
          .select()
          .single();
      return AssetEntity(
        id: response['id'] as String,
        farmId: response['farm_id'] as String,
        assetName: response['asset_name'] as String,
        assetType: response['asset_type'] as String,
        manufacturer: response['manufacturer'] as String?,
        model: response['model'] as String?,
        yearPurchased: response['year_purchased'] as int?,
        condition: response['condition'] as String?,
        lastMaintenanceDate: response['last_maintenance_date'] != null
            ? DateTime.parse(response['last_maintenance_date'] as String)
            : null,
        notes: response['notes'] as String?,
        isActive: response['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(response['created_at'] as String),
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to create asset: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create asset: $e');
    }
  }

  // ── Production Records ──

  @override
  Future<List<ProductionEntity>> getProductionRecords({required String farmId}) async {
    try {
      final response = await _client
          .schema('farm_management').from('production_records')
          .select()
          .eq('farm_id', farmId)
          .order('created_at', ascending: false)
          .limit(100);
      return (response as List)
          .cast<Map<String, dynamic>>()
          .map((row) => ProductionEntity(
                id: row['id'] as String,
                activityId: row['activity_id'] as String?,
                variantId: row['variant_id'] as String?,
                outputCommodityId: row['output_commodity_id'] as String?,
                quantity: (row['quantity'] as num?)?.toDouble(),
                unitId: row['unit_id'] as String?,
                categoryId: row['category_id'] as String?,
                assetId: row['asset_id'] as String?,
                fieldId: row['field_id'] as String?,
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load production records: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load production records: $e');
    }
  }

  @override
  Future<ProductionEntity> recordProduction({
    required String farmId,
    required ProductionEntity production,
  }) async {
    try {
      // Only documented production_records columns are sent. Nullable
      // context is omitted so invalid payloads (e.g. non-UUID category/unit
      // labels) can never reach the backend FK columns. `entity_id` is left
      // to the server default (core.auth_user_id()).
      final payload = <String, dynamic>{
        'farm_id': farmId,
        'quantity': production.quantity,
        if (production.outputCommodityId != null)
          'output_commodity_id': production.outputCommodityId,
        if (production.variantId != null) 'variant_id': production.variantId,
        if (production.unitId != null) 'unit_id': production.unitId,
        if (production.categoryId != null) 'category_id': production.categoryId,
        if (production.assetId != null) 'asset_id': production.assetId,
        if (production.fieldId != null) 'field_id': production.fieldId,
        if (production.activityId != null) 'activity_id': production.activityId,
      };
      final response = await _client
          .schema('farm_management').from('production_records')
          .insert(payload)
          .select()
          .single();
      // Auto-trigger KPI update
      unawaited(_kpiService.updateProductionKpis(
        farmId: farmId,
        quantity: production.quantity,
        categoryId: production.categoryId,
        unitId: production.unitId,
      ));
      return ProductionEntity(
        id: response['id'] as String,
        activityId: response['activity_id'] as String?,
        variantId: response['variant_id'] as String?,
        outputCommodityId: response['output_commodity_id'] as String?,
        quantity: (response['quantity'] as num?)?.toDouble(),
        unitId: response['unit_id'] as String?,
        categoryId: response['category_id'] as String?,
        assetId: response['asset_id'] as String?,
        fieldId: response['field_id'] as String?,
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to record production: ${e.message}');
    } catch (e) {
      throw Exception('Failed to record production: $e');
    }
  }

  // ── Reference Data (Taxonomy) ──

  @override
  Future<List<({String id, String name, String category})>> getCommodities() async {
    try {
      final rows = await _client
          .schema('core')
          .from('commodities')
          .select('id, name, category')
          .eq('is_active', true)
          .order('name', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map((r) => (
                id: r['id'].toString(),
                name: r['name']?.toString() ?? '',
                category: r['category']?.toString() ?? '',
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load commodities: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load commodities: $e');
    }
  }

  @override
  Future<List<({String id, String name})>> getUnits() async {
    try {
      final rows = await _client
          .schema('core')
          .from('units')
          .select('id, name')
          .order('name', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map((r) => (
                id: r['id'].toString(),
                name: r['name']?.toString() ?? '',
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load units: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load units: $e');
    }
  }

  // ── Activities ──

  /// Query activities for a farm.
  ///
  /// Farm filtering is performed SERVER-SIDE by resolving the farm's
  /// asset/plan IDs first, then filtering activities on `asset_id` /
  /// `plan_id` via PostgREST `.in()`. The whole activities table is
  /// never fetched. Deleted activities are excluded
  /// (`.eq('is_deleted', false)`).
  ///
  /// ⚠️ LIMITATION (documented contract): the activities table has no
  /// farm_id / field_id / crop_or_livestock_id columns, so activities
  /// linked to NEITHER an asset nor a plan cannot be farm-associated
  /// server-side and are not returned. This matches the documented
  /// contract that activities belong to a farm through an asset/plan.
  Future<List<ActivityModel>> _queryFarmActivities({
    required String farmId,
    void Function(dynamic query)? extraFilter,
    int limit = 100,
  }) async {
    // Resolve the farm's asset IDs and plan IDs.
    final assetRows = await _client
        .schema('farm_management').from('assets')
        .select('id')
        .eq('farm_id', farmId);
    final planRows = await _client
        .schema('farm_management').from('plans')
        .select('id')
        .eq('farm_id', farmId);
    final assetIds = (assetRows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['id'] as String)
        .toList();
    final planIds = (planRows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['id'] as String)
        .toList();

    // Farm has no assets/plans → no activities can be associated.
    if (assetIds.isEmpty && planIds.isEmpty) return const [];

    final orConditions = <String>[
      if (assetIds.isNotEmpty) 'asset_id.in.(${assetIds.join(',')})',
      if (planIds.isNotEmpty) 'plan_id.in.(${planIds.join(',')})',
    ];

    var query = _client
        .schema('farm_management').from('activities')
        .select('id, activity_type_id, performed_at, notes, asset_id, plan_id')
        .eq('is_deleted', false)
        .or(orConditions.join(','));
    extraFilter?.call(query);
    final response = await query.order('performed_at', ascending: false).limit(limit);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map((row) => activityFromRow(row, farmId: farmId))
        .toList();
  }

  @override
  Future<List<ActivityModel>> getActivities({required String farmId}) async {
    try {
      return await _queryFarmActivities(farmId: farmId, limit: 100);
    } on PostgrestException catch (e) {
      throw Exception('Failed to load activities: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load activities: $e');
    }
  }

  @override
  Future<ActivityModel> createActivity({required ActivityModel activity}) async {
    try {
      if (activity.assetId != null) {
        final assetCheck = await _client
            .schema('farm_management').from('assets')
            .select('id')
            .eq('id', activity.assetId!)
            .maybeSingle();
        if (assetCheck == null) throw Exception('Asset not found');
      }
      if (activity.planId != null) {
        final planCheck = await _client
            .schema('farm_management').from('plans')
            .select('id')
            .eq('id', activity.planId!)
            .maybeSingle();
        if (planCheck == null) throw Exception('Plan not found');
      }
      final inserted = await _client
          .schema('farm_management').from('activities')
          .insert(buildActivityInsertPayload(activity))
          .select('''
            id, activity_type_id, performed_at, notes, asset_id, plan_id
          ''')
          .single();

      // Backend-generated ID is mapped here (activityFromRow reads `id`).
      final createdActivity = activityFromRow(inserted);

      // Persist attribute values if present
      if (activity.attributeValues.isNotEmpty) {
        for (final entry in activity.attributeValues.entries) {
          final key = entry.key;
          final value = entry.value;
          if (value == null) continue;
          final row = <String, dynamic>{
            'activity_id': createdActivity.id,
            'attribute_id': key,
          };
          if (value is String) {
            row['value_text'] = value;
          } else if (value is num) {
            row['value_number'] = value.toDouble();
          } else if (value is bool) {
            row['value_boolean'] = value;
          } else if (value is DateTime) {
            row['value_text'] = value.toIso8601String();
          } else {
            row['value_text'] = value.toString();
          }
          await _client.schema('farm_management').from('activity_values').insert(row);
        }
      }
      return createdActivity;
    } on PostgrestException catch (e) {
      throw Exception('Failed to create activity: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create activity: $e');
    }
  }

  // ── Activity Attribute Values ──

  @override
  Future<void> persistActivityValues({
    required String farmId,
    required String activityId,
    required Map<String, dynamic> values,
  }) async {
    if (values.isEmpty) return;
    try {
      for (final entry in values.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value == null) continue;
        final row = <String, dynamic>{
          'activity_id': activityId,
          'attribute_id': key,
        };
        if (value is String) {
          row['value_text'] = value;
        } else if (value is num) {
          row['value_number'] = value.toDouble();
        } else if (value is bool) {
          row['value_boolean'] = value;
        } else if (value is DateTime) {
          row['value_text'] = value.toIso8601String();
        } else {
          row['value_text'] = value.toString();
        }
        await _client.schema('farm_management').from('activity_values').insert(row);
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to persist activity values: ${e.message}');
    } catch (e) {
      throw Exception('Failed to persist activity values: $e');
    }
  }

  // ── Crop / Livestock Detail ──

  @override
  Future<CropEntity?> getCropById({
    required String farmId,
    required String cropId,
  }) async {
    try {
      final response = await _client
          .schema('farm_management').from('crops')
          .select()
          .eq('id', cropId)
          .eq('farm_id', farmId)
          .maybeSingle();
      if (response == null) return null;
      final row = response;
      return CropEntity(
        id: row['id'] as String,
        farmId: row['farm_id'] as String,
        fieldId: row['field_id'] as String?,
        cropName: row['crop_name'] as String,
        variety: row['variety'] as String?,
        plantingDate: DateTime.parse(row['planting_date'] as String),
        expectedHarvestDate: row['expected_harvest_date'] != null
            ? DateTime.parse(row['expected_harvest_date'] as String)
            : null,
        areaPlanted: (row['area_planted'] as num?)?.toDouble(),
        quantityPlanted: (row['quantity_planted'] as num?)?.toDouble(),
        unit: row['unit'] as String?,
        status: _parseCropStatus(row['status'] as String?),
        notes: row['notes'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to load crop: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load crop: $e');
    }
  }

  // ── Report Aggregations ──

  @override
  Future<Map<String, dynamic>> getActivityReport({required String farmId}) async {
    try {
      // Activities don't have a farm_id column; fetch all and filter via asset/plan
      final response = await _client
          .schema('farm_management').from('activities')
          .select('''
            id, activity_type_id, performed_at, notes, asset_id, plan_id,
            asset:asset_id(farm_id), plan:plan_id(farm_id)
          ''')
          .order('performed_at', ascending: false);
      final allActivities = (response as List).cast<Map<String, dynamic>>();
      final filtered = allActivities.where((row) {
        final assetFarmId = (row['asset'] as Map<String, dynamic>?)?['farm_id'] as String?;
        final planFarmId = (row['plan'] as Map<String, dynamic>?)?['farm_id'] as String?;
        return assetFarmId == farmId || planFarmId == farmId;
      }).toList();
      return {
        'total_activities': filtered.length,
        'activities': filtered,
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to load activity report: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load activity report: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getProductionReport({required String farmId}) async {
    try {
      final response = await _client
          .schema('farm_management').from('production_records')
          .select()
          .eq('farm_id', farmId)
          .order('created_at', ascending: false);
      final records = (response as List).cast<Map<String, dynamic>>();
      double totalProduction = 0;
      for (final r in records) {
        totalProduction += (r['quantity'] as num?)?.toDouble() ?? 0;
      }
      return {
        'total_production': totalProduction,
        'total_records': records.length,
        'records': records,
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to load production report: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load production report: $e');
    }
  }

  // ── Inventory / Stock ──

  @override
  Future<Map<String, dynamic>> consumeStock({
    required String farmId,
    required String assetId,
    required double quantity,
    String? activityId,
    String? unitId,
    String? description,
  }) async {
    try {
      final currentAsset = await _client
          .schema('farm_management').from('assets')
          .select('id, quantity')
          .eq('id', assetId)
          .eq('farm_id', farmId)
          .single();
      final currentQty = (currentAsset['quantity'] as num?)?.toDouble() ?? 0;
      if (currentQty < quantity) {
        return {
          'success': false,
          'error': 'Insufficient stock. Available: $currentQty, Requested: $quantity',
          'new_balance': currentQty,
        };
      }
      final newBalance = currentQty - quantity;
      await _client
          .schema('farm_management').from('assets')
          .update({
            'quantity': newBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', assetId);
      if (activityId != null) {
        await _client.schema('farm_management').from('production_records').insert({
          'farm_id': farmId,
          'asset_id': assetId,
          'activity_id': activityId,
          'quantity': -quantity,
          'unit_id': unitId,
          'source_type': 'consumption',
        });
      }
      return {'success': true, 'new_balance': newBalance, 'quantity': -quantity};
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'new_balance': 0};
    }
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
    try {
      final currentAsset = await _client
          .schema('farm_management').from('assets')
          .select('id, quantity')
          .eq('id', assetId)
          .eq('farm_id', farmId)
          .single();
      final currentQty = (currentAsset['quantity'] as num?)?.toDouble() ?? 0;
      final newBalance = currentQty + quantity;
      await _client
          .schema('farm_management').from('assets')
          .update({
            'quantity': newBalance,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', assetId);
      return {'success': true, 'new_balance': newBalance, 'quantity': quantity};
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'new_balance': 0};
    }
  }

  @override
  Future<Map<String, double>> getAvailableStock({required String farmId}) async {
    try {
      final result = await _client
          .schema('farm_management').from('assets')
          .select('id, quantity')
          .eq('farm_id', farmId)
          .gt('quantity', 0);
      final stock = <String, double>{};
      for (final row in (result as List).cast<Map<String, dynamic>>()) {
        stock[row['id'] as String] = (row['quantity'] as num?)?.toDouble() ?? 0;
      }
      return stock;
    } catch (e) {
      return {};
    }
  }

  // ── Financial Records ──

  @override
  Future<void> recordFinancialTransaction({
    required String farmId,
    required String recordType,
    required double amount,
    required String description,
    String? activityId,
  }) async {
    try {
      await _client.schema('farm_management').from('financial_records').insert({
        'farm_id': farmId,
        'activity_id': activityId,
        'record_type': recordType,
        'amount': amount,
        'description': description,
        'recorded_at': DateTime.now().toIso8601String(),
      });
      // Auto-trigger KPI update
      unawaited(_kpiService.updateFinancialKpis(
        farmId: farmId,
        recordType: recordType,
        amount: amount,
      ));
    } on PostgrestException catch (e) {
      throw Exception('Failed to record financial transaction: ${e.message}');
    } catch (e) {
      throw Exception('Failed to record financial transaction: $e');
    }
  }

  // ── KPI Automation (delegated to KpiAutomationService) ──

  @override
  Future<void> updateProductionKpis({
    required String farmId,
    double? quantity,
  }) async {
    await _kpiService.updateProductionKpis(farmId: farmId, quantity: quantity);
  }

  @override
  Future<void> updateFinancialKpis({
    required String farmId,
    String? recordType,
    double? amount,
  }) async {
    await _kpiService.updateFinancialKpis(
      farmId: farmId,
      recordType: recordType,
      amount: amount,
    );
  }

  @override
  Future<void> updateStockValueKpi({required String farmId}) async {
    await _kpiService.updateStockValueKpi(farmId: farmId);
  }

  // ── Cross-Module ──

  @override
  Future<void> syncMarketplaceListing({required String farmId}) async {
    try {
      await _client.schema('farm_management').from('farm_reports').insert({
        'farm_id': farmId,
        'report_type': 'marketplace_sync',
        'report_date': DateTime.now().toIso8601String(),
        'description': 'Marketplace listing sync initiated from app',
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to sync marketplace listing: ${e.message}');
    } catch (e) {
      throw Exception('Failed to sync marketplace listing: $e');
    }
  }

  // ════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ════════════════════════════════════════════════════════════

  FarmEntity _mapFarmRow(Map<String, dynamic> row) {
    return FarmEntity(
      id: row['id'] as String,
      farmName: row['farm_name'] as String,
      description: row['description'] as String?,
      size: (row['size'] as num?)?.toDouble(),
      countyId: row['county_id'] as String?,
      subCountyId: row['sub_county_id'] as String?,
      wardId: row['ward_id'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      isVerified: row['is_verified'] as bool? ?? false,
    );
  }

  /// Maps a farm_management.fields row to [FieldEntity] against the
  /// authoritative backend contract:
  ///   name ↔ fieldName, size ↔ acreage, field_type ↔ type,
  ///   description ↔ notes, soil_type ↔ soilType, is_active ↔ isActive,
  ///   unit_id ↔ unitId.
  /// `current_crop` and `status` are NOT backend columns → currentCrop is
  /// left null and status is derived from is_active.
  FieldEntity _mapFieldRow(Map<String, dynamic> row) {
    return FieldEntity(
      id: row['id'] as String,
      farmId: row['farm_id'] as String,
      fieldName: row['name'] as String,
      acreage: (row['size'] as num?)?.toDouble(),
      soilType: row['soil_type'] as String?,
      currentCrop: null,
      type: row['field_type'] as String?,
      notes: row['description'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      unitId: row['unit_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}