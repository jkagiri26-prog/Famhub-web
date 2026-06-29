import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/entities/asset_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/field_entity.dart';
import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';
import 'package:famhub_app/features/farm_management/domain/entities/farm_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/farm_management/domain/enums/crop_status.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
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

  // ── Dashboard ──

  @override
  Future<FarmDashboardSummary> getDashboardSummary({required String farmId}) async {
    try {
      final response = await _client
          .from('farm_kpis')
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
      final response = await _client
          .from('activities')
          .select('''id, activity_type_id, performed_at, notes, asset_id, plan_id,
            asset:asset_id(farm_id), plan:plan_id(farm_id)''')
          .gte('performed_at', startOfDay.toIso8601String())
          .order('performed_at', ascending: false)
          .limit(50);
      final List<ActivityModel> activities = [];
      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        final assetFarmId = (row['asset'] as Map<String, dynamic>?)?['farm_id'] as String?;
        final planFarmId = (row['plan'] as Map<String, dynamic>?)?['farm_id'] as String?;
        if (assetFarmId == farmId || planFarmId == farmId) {
          activities.add(ActivityModel(id: row['id'] as String, activityTypeId: row['activity_type_id'] as String,
              performedAt: DateTime.parse(row['performed_at'] as String), notes: row['notes'] as String?,
              assetId: row['asset_id'] as String?, planId: row['plan_id'] as String?));
        }
      }
      return activities;
    } on PostgrestException catch (e) {
      throw Exception('Failed to load today activities: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load today activities: $e');
    }
  }

  @override
  Future<List<FarmEntity>> getUserFarms() async {
    try {
      final response = await _client.from('farms').select().eq('is_active', true).order('farm_name', ascending: true);
      return (response as List).cast<Map<String, dynamic>>().map((row) => FarmEntity(id: row['id'] as String,
          farmName: row['farm_name'] as String, description: row['description'] as String?,
          size: (row['size'] as num?)?.toDouble(), isActive: row['is_active'] as bool? ?? true,
          isVerified: row['is_verified'] as bool? ?? false)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load user farms: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load user farms: $e');
    }
  }

  @override
  Future<void> recordProduction({required String farmId, required ProductionEntity production}) async {
    try {
      await _client.from('production_records').insert({
        'farm_id': farmId, 'variant_id': production.variantId, 'quantity': production.quantity,
        'unit_id': production.unitId, 'category_id': production.categoryId, 'asset_id': production.assetId,
        'field_id': production.fieldId, 'activity_id': production.activityId,
        'created_at': DateTime.now().toIso8601String(),
      });
      // Auto-trigger KPI update
      unawaited(_kpiService.updateProductionKpis(farmId: farmId, quantity: production.quantity, categoryId: production.categoryId, unitId: production.unitId));
    } on PostgrestException catch (e) {
      throw Exception('Failed to record production: ${e.message}');
    } catch (e) {
      throw Exception('Failed to record production: $e');
    }
  }

  @override
  Future<void> createActivity({required String farmId, required ActivityModel activity}) async {
    try {
      if (activity.assetId != null) {
        final assetCheck = await _client.from('assets').select('id').eq('id', activity.assetId!).eq('farm_id', farmId).maybeSingle();
        if (assetCheck == null) throw Exception('Asset does not belong to the specified farm');
      }
      if (activity.planId != null) {
        final planCheck = await _client.from('plans').select('id').eq('id', activity.planId!).eq('farm_id', farmId).maybeSingle();
        if (planCheck == null) throw Exception('Plan does not belong to the specified farm');
      }
      final inserted = await _client.from('activities').insert({
        'activity_type_id': activity.activityTypeId, 'performed_at': activity.performedAt.toIso8601String(),
        'notes': activity.notes, 'asset_id': activity.assetId, 'plan_id': activity.planId,
      }).select('id').single();
      if (activity.attributeValues.isNotEmpty) {
        final activityId = inserted['id'] as String;
        for (final entry in activity.attributeValues.entries) {
          final key = entry.key;
          final value = entry.value;
          if (value == null) continue;
          final row = <String, dynamic>{'activity_id': activityId, 'attribute_id': key};
          if (value is String) {
            row['value_text'] = value;
          } else if (value is num) row['value_number'] = value.toDouble();
          else if (value is bool) row['value_boolean'] = value;
          else if (value is DateTime) row['value_text'] = value.toIso8601String();
          else row['value_text'] = value.toString();
          await _client.from('activity_values').insert(row);
        }
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to create activity: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create activity: $e');
    }
  }

    // ── Crops ──

  @override
  Future<List<CropEntity>> getCrops({required String farmId}) async {
    try {
      final response = await _client.from('crops').select().eq('farm_id', farmId).order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>().map((row) => CropEntity(id: row['id'] as String, farmId: row['farm_id'] as String,
          fieldId: row['field_id'] as String?, cropName: row['crop_name'] as String, variety: row['variety'] as String?,
          plantingDate: DateTime.parse(row['planting_date'] as String),
          expectedHarvestDate: row['expected_harvest_date'] != null ? DateTime.parse(row['expected_harvest_date'] as String) : null,
          areaPlanted: (row['area_planted'] as num?)?.toDouble(), quantityPlanted: (row['quantity_planted'] as num?)?.toDouble(),
          unit: row['unit'] as String?, status: _parseCropStatus(row['status'] as String?), notes: row['notes'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String))).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load crops: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load crops: $e');
    }
  }

  CropStatus _parseCropStatus(String? status) {
    switch (status) {
      case 'growing': return CropStatus.growing;
      case 'harvested': return CropStatus.harvested;
      case 'failed': return CropStatus.failed;
      default: return CropStatus.planted;
    }
  }

  @override
  Future<void> createCrop({required String farmId, required CropEntity crop}) async {
    try {
      await _client.from('crops').insert({
        'farm_id': farmId, 'field_id': crop.fieldId, 'crop_name': crop.cropName, 'variety': crop.variety,
        'planting_date': crop.plantingDate.toIso8601String(),
        'expected_harvest_date': crop.expectedHarvestDate?.toIso8601String(),
        'area_planted': crop.areaPlanted, 'quantity_planted': crop.quantityPlanted, 'unit': crop.unit,
        'status': crop.status.name, 'notes': crop.notes,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to create crop: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create crop: $e');
    }
  }

  // ── Livestock ──

  @override
  Future<List<LivestockEntity>> getLivestock({required String farmId}) async {
    try {
      final response = await _client.from('livestock').select().eq('farm_id', farmId).order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>().map((row) => LivestockEntity(id: row['id'] as String, farmId: row['farm_id'] as String,
          species: row['species'] as String, breed: row['breed'] as String?, count: row['count'] as int,
          dateOfBirth: row['date_of_birth'] != null ? DateTime.parse(row['date_of_birth'] as String) : null,
          healthStatus: row['health_status'] as String?, purpose: row['purpose'] as String?, notes: row['notes'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String))).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load livestock: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load livestock: $e');
    }
  }

  @override
  Future<void> createLivestock({required String farmId, required LivestockEntity livestock}) async {
    try {
      await _client.from('livestock').insert({
        'farm_id': farmId, 'species': livestock.species, 'breed': livestock.breed, 'count': livestock.count,
        'date_of_birth': livestock.dateOfBirth?.toIso8601String(), 'health_status': livestock.healthStatus,
        'purpose': livestock.purpose, 'notes': livestock.notes,
      });
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
      final response = await _client.from('assets').select().eq('farm_id', farmId).order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>().map((row) => AssetEntity(id: row['id'] as String, farmId: row['farm_id'] as String,
          assetName: row['asset_name'] as String, assetType: row['asset_type'] as String, manufacturer: row['manufacturer'] as String?,
          model: row['model'] as String?, yearPurchased: row['year_purchased'] as int?, condition: row['condition'] as String?,
          lastMaintenanceDate: row['last_maintenance_date'] != null ? DateTime.parse(row['last_maintenance_date'] as String) : null,
          notes: row['notes'] as String?, isActive: row['is_active'] as bool? ?? true,
          createdAt: DateTime.parse(row['created_at'] as String))).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load assets: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load assets: $e');
    }
  }

  @override
  Future<void> createAsset({required String farmId, required AssetEntity asset}) async {
    try {
      await _client.from('assets').insert({
        'farm_id': farmId, 'asset_name': asset.assetName, 'asset_type': asset.assetType,
        'manufacturer': asset.manufacturer, 'model': asset.model, 'year_purchased': asset.yearPurchased,
        'condition': asset.condition, 'last_maintenance_date': asset.lastMaintenanceDate?.toIso8601String(),
        'notes': asset.notes, 'is_active': asset.isActive,
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to create asset: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create asset: $e');
    }
  }

  // ── Fields ──

  @override
  Future<List<FieldEntity>> getFields({required String farmId}) async {
    try {
      final response = await _client.from('fields').select().eq('farm_id', farmId).order('field_name', ascending: true);
      return (response as List).cast<Map<String, dynamic>>().map((row) => FieldEntity(id: row['id'] as String, farmId: row['farm_id'] as String,
          fieldName: row['field_name'] as String, acreage: (row['acreage'] as num?)?.toDouble(), soilType: row['soil_type'] as String?,
          currentCrop: row['current_crop'] as String?, status: row['status'] as String? ?? 'active', notes: row['notes'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String))).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load fields: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load fields: $e');
    }
  }

  // ── Production Records ──

  @override
  Future<List<ProductionEntity>> getProductionRecords({required String farmId}) async {
    try {
      final response = await _client.from('production_records').select().eq('farm_id', farmId).order('created_at', ascending: false).limit(100);
            return (response as List).cast<Map<String, dynamic>>().map((row) => ProductionEntity(id: row['id'] as String,
          activityId: row['activity_id'] as String?, variantId: row['variant_id'] as String?,
          quantity: (row['quantity'] as num?)?.toDouble(), unitId: row['unit_id'] as String?,
          categoryId: row['category_id'] as String?, assetId: row['asset_id'] as String?,
          fieldId: row['field_id'] as String?)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load production records: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load production records: $e');
    }
  }

  // ── Activities ──

  @override
  Future<List<ActivityModel>> getActivities({required String farmId}) async {
    try {
      final response = await _client.from('activities').select('''id, activity_type_id, performed_at, notes, asset_id, plan_id,
            asset:asset_id(farm_id), plan:plan_id(farm_id)''').order('performed_at', ascending: false).limit(100);
      final List<ActivityModel> activities = [];
      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        final assetFarmId = (row['asset'] as Map<String, dynamic>?)?['farm_id'] as String?;
        final planFarmId = (row['plan'] as Map<String, dynamic>?)?['farm_id'] as String?;
        if (assetFarmId == farmId || planFarmId == farmId) {
          activities.add(ActivityModel(id: row['id'] as String, activityTypeId: row['activity_type_id'] as String,
              performedAt: DateTime.parse(row['performed_at'] as String), notes: row['notes'] as String?,
              assetId: row['asset_id'] as String?, planId: row['plan_id'] as String?));
        }
      }
      return activities;
    } on PostgrestException catch (e) {
      throw Exception('Failed to load activities: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load activities: $e');
    }
  }

  // ── Activity Attribute Values ──

  @override
  Future<void> persistActivityValues({required String farmId, required String activityId, required Map<String, dynamic> values}) async {
    if (values.isEmpty) return;
    try {
      for (final entry in values.entries) {
        final key = entry.key;
        final value = entry.value;
        if (value == null) continue;
        final row = <String, dynamic>{'activity_id': activityId, 'attribute_id': key};
        if (value is String) {
          row['value_text'] = value;
        } else if (value is num) row['value_number'] = value.toDouble();
        else if (value is bool) row['value_boolean'] = value;
        else if (value is DateTime) row['value_text'] = value.toIso8601String();
        else row['value_text'] = value.toString();
        await _client.from('activity_values').insert(row);
      }
    } on PostgrestException catch (e) {
      throw Exception('Failed to persist activity values: ${e.message}');
    } catch (e) {
      throw Exception('Failed to persist activity values: $e');
    }
  }

  // ── Inventory / Stock ──

  @override
  Future<Map<String, dynamic>> consumeStock({required String farmId, required String assetId, required double quantity,
      String? activityId, String? unitId, String? description}) async {
    try {
      final currentAsset = await _client.from('assets').select('id, quantity').eq('id', assetId).eq('farm_id', farmId).single();
      final currentQty = (currentAsset['quantity'] as num?)?.toDouble() ?? 0;
      if (currentQty < quantity) return {'success': false, 'error': 'Insufficient stock. Available: $currentQty, Requested: $quantity', 'new_balance': currentQty};
      final newBalance = currentQty - quantity;
      await _client.from('assets').update({'quantity': newBalance, 'updated_at': DateTime.now().toIso8601String()}).eq('id', assetId);
      if (activityId != null) {
        await _client.from('production_records').insert({'farm_id': farmId, 'asset_id': assetId, 'activity_id': activityId,
            'quantity': -quantity, 'unit_id': unitId, 'source_type': 'consumption', 'created_at': DateTime.now().toIso8601String()});
      }
      return {'success': true, 'new_balance': newBalance, 'quantity': -quantity};
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'new_balance': 0};
    }
  }

  @override
  Future<Map<String, dynamic>> addStock({required String farmId, required String assetId, required double quantity,
      String? activityId, String? unitId, String? description}) async {
    try {
      final currentAsset = await _client.from('assets').select('id, quantity').eq('id', assetId).eq('farm_id', farmId).single();
      final currentQty = (currentAsset['quantity'] as num?)?.toDouble() ?? 0;
      final newBalance = currentQty + quantity;
      await _client.from('assets').update({'quantity': newBalance, 'updated_at': DateTime.now().toIso8601String()}).eq('id', assetId);
      return {'success': true, 'new_balance': newBalance, 'quantity': quantity};
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'new_balance': 0};
    }
  }

  @override
  Future<Map<String, double>> getAvailableStock({required String farmId}) async {
    try {
      final result = await _client.from('assets').select('id, quantity').eq('farm_id', farmId).gt('quantity', 0);
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
  Future<void> recordFinancialTransaction({required String farmId, required String recordType, required double amount,
      required String description, String? activityId}) async {
    try {
      await _client.from('financial_records').insert({'farm_id': farmId, 'activity_id': activityId, 'record_type': recordType,
          'amount': amount, 'description': description, 'recorded_at': DateTime.now().toIso8601String()});
      // Auto-trigger KPI update
      unawaited(_kpiService.updateFinancialKpis(farmId: farmId, recordType: recordType, amount: amount));
    } on PostgrestException catch (e) {
      throw Exception('Failed to record financial transaction: ${e.message}');
    } catch (e) {
      throw Exception('Failed to record financial transaction: $e');
    }
  }

  // ── KPI Automation (delegated to KpiAutomationService) ──

  @override
  Future<void> updateProductionKpis({required String farmId, double? quantity}) async {
    await _kpiService.updateProductionKpis(farmId: farmId, quantity: quantity);
  }

  @override
  Future<void> updateFinancialKpis({required String farmId, String? recordType, double? amount}) async {
    await _kpiService.updateFinancialKpis(farmId: farmId, recordType: recordType, amount: amount);
  }

  @override
  Future<void> updateStockValueKpi({required String farmId}) async {
    await _kpiService.updateStockValueKpi(farmId: farmId);
  }

  // ── Cross-Module ──

  @override
  Future<void> syncMarketplaceListing({required String farmId}) async {
    try {
      await _client.from('farm_reports').insert({'farm_id': farmId, 'report_type': 'marketplace_sync',
          'report_date': DateTime.now(), 'description': 'Marketplace listing sync initiated from app'});
    } on PostgrestException catch (e) {
      throw Exception('Failed to sync marketplace listing: ${e.message}');
    } catch (e) {
      throw Exception('Failed to sync marketplace listing: $e');
    }
  }
}
