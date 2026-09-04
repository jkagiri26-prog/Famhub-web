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

  /// Creates a farm through the verified backend RPC
  /// `commerce.create_farm_with_auto_entity(farm_data jsonb)`.
  ///
  /// The backend creates the farm, resolves entity/ownership, and creates
  /// exactly one Main Field. It returns TABLE(farm_id uuid, entity_id uuid).
  Future<(String farmId, String entityId)> _createFarmViaRpc(FarmEntity farm) async {
    final countyId = farm.countyId;
    final subCountyId = farm.subCountyId;
    final wardId = farm.wardId;
    if (countyId == null || subCountyId == null || wardId == null) {
      throw Exception(
        'Farm location is incomplete. Complete your profile location '
        '(County, Sub-County, Ward) before creating a farm.',
      );
    }
    try {
      final response = await _client
          .schema('commerce')
          .rpc('create_farm_with_auto_entity', params: {
        'farm_data': {
          'farm_name': farm.farmName,
          'description': farm.description,
          'size': farm.size,
          'county_id': countyId,
          'sub_county_id': subCountyId,
          'ward_id': wardId,
          'is_active': farm.isActive,
          'is_verified': farm.isVerified,
        },
      });
      // RPC returns a row set: data[0]['farm_id'], data[0]['entity_id'].
      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) {
        throw Exception('Farm RPC returned no farm_id');
      }
      final farmId = rows.first['farm_id']?.toString();
      final entityId = rows.first['entity_id']?.toString();
      if (farmId == null || farmId.isEmpty) {
        throw Exception('Farm RPC returned no farm_id');
      }
      return (farmId, entityId ?? '');
    } on PostgrestException catch (e) {
      throw Exception('Failed to create farm: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create farm: $e');
    }
  }

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
    // Authoritative flow: the backend creates the farm AND its single Main
    // Field atomically. The frontend NEVER inserts a Main Field itself.
    final (farmId, _) = await _createFarmViaRpc(farm);

    final createdFarm = await getFarm(farmId: farmId);
    if (createdFarm == null) {
      throw Exception('Farm was created but could not be reloaded');
    }

    // Select the auto-created Main Field from the backend result.
    final fields = await getFields(farmId: farmId);
    if (fields.isEmpty) {
      throw Exception('Farm was created but the Main Field was not returned');
    }
    final mainField = fields.firstWhere(
      (f) => f.fieldName.toLowerCase().contains('main'),
      orElse: () => fields.first,
    );

    return (createdFarm, mainField);
  }

  @override
  Future<FarmEntity> createFarm({required FarmEntity farm}) async {
    final (farmId, _) = await _createFarmViaRpc(farm);
    final createdFarm = await getFarm(farmId: farmId);
    if (createdFarm == null) {
      throw Exception('Farm was created but could not be reloaded');
    }
    return createdFarm;
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
  //
  // Crops are farm INSTANCE records stored in `farm_management.assets`
  // with asset_type = 'crop'. The crop *kind* is the linked
  // core.item_variants row. There is no farm_management.crops table.

  Future<List<Map<String, dynamic>>> _fetchCropLivestockAssets({
    required String assetType,
    required String farmId,
    String? fieldId,
  }) async {
    var query = _client
        .schema('farm_management').from('assets')
        .select('id, entity_id, farm_id, asset_type, variant_id, field_id, '
            'status, quantity, unit_id, metadata, created_at')
        .eq('farm_id', farmId)
        .eq('asset_type', assetType);
    if (fieldId != null) {
      query = query.eq('field_id', fieldId);
    }
    final response = await query.order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Resolves core.item_variants.id → display label for a set of variant
  /// ids by joining item_variants (id, name) with core.items (id, name).
  /// Falls back to the raw variant id when the catalog is unreachable.
  Future<Map<String, String>> _fetchVariantLabels(Set<String> variantIds) async {
    final ids = variantIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return const {};
    try {
      final variantRows = await _client
          .schema('core')
          .from('item_variants')
          .select('id, item_id, name')
          .inFilter('id', ids);
      final variants = (variantRows as List).cast<Map<String, dynamic>>();
      final itemIds = variants
          .map((v) => v['item_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet();
      final items = <String, String>{};
      if (itemIds.isNotEmpty) {
        final itemRows = await _client
            .schema('core')
            .from('items')
            .select('id, name')
            .inFilter('id', itemIds.toList());
        for (final row in (itemRows as List).cast<Map<String, dynamic>>()) {
          items[row['id'].toString()] = row['name']?.toString() ?? '';
        }
      }
      return {
        for (final v in variants)
          v['id'].toString(): [
            if (items[v['item_id']?.toString()]?.isNotEmpty ?? false)
              items[v['item_id']!.toString()]!,
            if ((v['name']?.toString() ?? '').isNotEmpty)
              v['name'].toString(),
          ].join(' ').trim(),
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to resolve variant labels: ${e.message}');
    } catch (e) {
      throw Exception('Failed to resolve variant labels: $e');
    }
  }

  @override
  Future<List<CropEntity>> getCrops({
    required String farmId,
    String? fieldId,
  }) async {
    try {
      final rows = await _fetchCropLivestockAssets(
        assetType: 'crop',
        farmId: farmId,
        fieldId: fieldId,
      );
      final labels = await _fetchVariantLabels(
        rows.map((r) => r['variant_id']?.toString() ?? '').toSet(),
      );
      return rows.map((row) => _cropFromAssetRow(row, labels)).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load crops: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load crops: $e');
    }
  }

  /// Maps a farm_management.assets row (asset_type='crop') into the
  /// existing [CropEntity] UI model. Display name resolves from the linked
  /// core.item_variants; extra attributes degrade gracefully.
  CropEntity _cropFromAssetRow(
    Map<String, dynamic> row,
    Map<String, String> variantLabels,
  ) {
    final variantId = row['variant_id']?.toString();
    final label = variantId == null ? '' : (variantLabels[variantId] ?? '');
    final metadata = row['metadata'] is Map
        ? (row['metadata'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now();
    return CropEntity(
      id: row['id'] as String,
      farmId: row['farm_id'] as String,
      entityId: row['entity_id'] as String?,
      fieldId: row['field_id'] as String?,
      cropName: label.isNotEmpty ? label : (metadata['name'] as String? ?? 'Crop'),
      variety: metadata['variety'] as String?,
      plantingDate:
          DateTime.tryParse(metadata['planting_date']?.toString() ?? '') ??
              createdAt,
      expectedHarvestDate:
          DateTime.tryParse(metadata['expected_harvest_date']?.toString() ?? ''),
      areaPlanted: (metadata['area_planted'] as num?)?.toDouble(),
      quantityPlanted: (row['quantity'] as num?)?.toDouble(),
      unit: row['unit_id']?.toString(),
      status: CropStatus.planted,
      notes: metadata['notes'] as String?,
      createdAt: createdAt,
    );
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
    if (crop.variantId == null) {
      throw Exception('Select a crop variant before adding it to the field.');
    }
    final assetId = await _createCropLivestockAsset(
      farmId: farmId,
      fieldId: crop.fieldId,
      variantId: crop.variantId!,
      assetType: 'crop',
    );
    return CropEntity(
      id: assetId,
      farmId: farmId,
      fieldId: crop.fieldId,
      cropName: crop.cropName,
      variety: crop.variety,
      plantingDate: crop.plantingDate,
      expectedHarvestDate: crop.expectedHarvestDate,
      areaPlanted: crop.areaPlanted,
      quantityPlanted: crop.quantityPlanted,
      unit: crop.unit,
      status: crop.status,
      notes: crop.notes,
      createdAt: crop.createdAt,
    );
  }

  /// Creates a crop/livestock INSTANCE via the verified RPC
  /// `farm_management.create_crop_livestock_asset(asset_data jsonb)`.
  /// Ownership/entity is derived server-side. Returns the created asset id
  /// parsed from the TABLE(asset_id uuid, entity_id uuid) result.
  Future<String> _createCropLivestockAsset({
    required String farmId,
    required String? fieldId,
    required String variantId,
    required String assetType,
  }) async {
    try {
      final response = await _client
          .schema('farm_management')
          .rpc('create_crop_livestock_asset', params: {
        'asset_data': {
          'farm_id': farmId,
          'field_id': fieldId,
          'variant_id': variantId,
          'asset_type': assetType,
        },
      });
      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) {
        throw Exception('Asset RPC returned no asset_id');
      }
      final assetId = rows.first['asset_id']?.toString();
      if (assetId == null || assetId.isEmpty) {
        throw Exception('Asset RPC returned no asset_id');
      }
      return assetId;
    } on PostgrestException catch (e) {
      throw Exception('Failed to create asset: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create asset: $e');
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
  //
  // Livestock are farm INSTANCE records stored in `farm_management.assets`
  // with asset_type = 'livestock'. The species *kind* is the linked
  // core.item_variants row. There is no farm_management.livestock table.

  /// Maps a farm_management.assets row (asset_type='livestock') into the
  /// existing [LivestockEntity] UI model. Display name resolves from the
  /// linked core.item_variants; count comes from asset.quantity.
  LivestockEntity _livestockFromAssetRow(
    Map<String, dynamic> row,
    Map<String, String> variantLabels,
  ) {
    final variantId = row['variant_id']?.toString();
    final label = variantId == null ? '' : (variantLabels[variantId] ?? '');
    final metadata = row['metadata'] is Map
        ? (row['metadata'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ??
        DateTime.now();
    return LivestockEntity(
      id: row['id'] as String,
      farmId: row['farm_id'] as String,
      entityId: row['entity_id'] as String?,
      fieldId: row['field_id'] as String?,
      variantId: variantId,
      species: label.isNotEmpty
          ? label
          : (metadata['species'] as String? ?? 'Livestock'),
      breed: metadata['breed'] as String?,
      count: (row['quantity'] as num?)?.toInt() ??
          (metadata['count'] as num?)?.toInt() ??
          1,
      dateOfBirth:
          DateTime.tryParse(metadata['date_of_birth']?.toString() ?? ''),
      healthStatus: metadata['health_status'] as String?,
      purpose: metadata['purpose'] as String?,
      notes: metadata['notes'] as String?,
      createdAt: createdAt,
    );
  }

  @override
  Future<List<LivestockEntity>> getLivestock({
    required String farmId,
    String? fieldId,
  }) async {
    try {
      final rows = await _fetchCropLivestockAssets(
        assetType: 'livestock',
        farmId: farmId,
        fieldId: fieldId,
      );
      final labels = await _fetchVariantLabels(
        rows.map((r) => r['variant_id']?.toString() ?? '').toSet(),
      );
      return rows.map((row) => _livestockFromAssetRow(row, labels)).toList();
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
    return getLivestock(farmId: farmId, fieldId: fieldId);
  }

  @override
  Future<LivestockEntity?> getLivestockById({
    required String farmId,
    required String livestockId,
  }) async {
    try {
      final response = await _client
          .schema('farm_management').from('assets')
          .select('id, entity_id, farm_id, asset_type, variant_id, field_id, '
              'status, quantity, unit_id, metadata, created_at')
          .eq('id', livestockId)
          .eq('farm_id', farmId)
          .eq('asset_type', 'livestock')
          .maybeSingle();
      if (response == null) return null;
      final labels = await _fetchVariantLabels({response['variant_id']?.toString() ?? ''});
      return _livestockFromAssetRow(response, labels);
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
    if (livestock.variantId == null) {
      throw Exception('Select a livestock variant before adding it to the field.');
    }
    final assetId = await _createCropLivestockAsset(
      farmId: farmId,
      fieldId: livestock.fieldId,
      variantId: livestock.variantId!,
      assetType: 'livestock',
    );
    return LivestockEntity(
      id: assetId,
      farmId: farmId,
      fieldId: livestock.fieldId,
      variantId: livestock.variantId,
      species: livestock.species,
      breed: livestock.breed,
      count: livestock.count,
      dateOfBirth: livestock.dateOfBirth,
      healthStatus: livestock.healthStatus,
      purpose: livestock.purpose,
      notes: livestock.notes,
      createdAt: livestock.createdAt,
    );
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
      // Authoritative contract: production is created EXPLICITLY from an
      // existing activity via the overloaded jsonb RPC
      // farm_management.create_production_record(p_production_data jsonb).
      // The backend derives farm/field/asset/entity context from the
      // activity → asset chain. Never send client ownership context.
      if (production.activityId == null || production.activityId!.isEmpty) {
        throw Exception('Production must be recorded from an existing activity.');
      }

      final payload = <String, dynamic>{
        'activity_id': production.activityId,
        if (production.quantity != null) 'quantity': production.quantity,
        if (production.unitId != null) 'unit_id': production.unitId,
        if (production.sourceType != null) 'source_type': production.sourceType,
        if (production.outputCommodityId != null)
          'output_commodity_id': production.outputCommodityId,
      };

      final response = await _client
          .schema('farm_management')
          .rpc('create_production_record', params: {'p_production_data': payload});

      // RPC returns a SCALAR UUID — use the returned value directly.
      final productionId = response?.toString().trim();
      if (productionId == null || productionId.isEmpty || productionId == 'null') {
        throw Exception('Production RPC returned no production id');
      }

      unawaited(_kpiService.updateProductionKpis(
        farmId: farmId,
        quantity: production.quantity,
        categoryId: production.categoryId,
        unitId: production.unitId,
      ));

      return ProductionEntity(
        id: productionId,
        activityId: production.activityId,
        variantId: production.variantId,
        outputCommodityId: production.outputCommodityId,
        quantity: production.quantity,
        unitId: production.unitId,
        categoryId: production.categoryId,
        assetId: production.assetId,
        fieldId: production.fieldId,
        sourceType: production.sourceType,
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

  @override
  Future<List<({String id, String itemName, String variantName})>> getVariants() async {
    try {
      final variantRows = await _client
          .schema('core')
          .from('item_variants')
          .select('id, item_id, name')
          .order('name', ascending: true);
      final variants = (variantRows as List).cast<Map<String, dynamic>>();
      final itemIds = variants
          .map((v) => v['item_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet();
      final items = <String, String>{};
      if (itemIds.isNotEmpty) {
        final itemRows = await _client
            .schema('core')
            .from('items')
            .select('id, name')
            .inFilter('id', itemIds.toList());
        for (final row in (itemRows as List).cast<Map<String, dynamic>>()) {
          items[row['id'].toString()] = row['name']?.toString() ?? '';
        }
      }
      return variants.map((v) => (
            id: v['id'].toString(),
            itemName: items[v['item_id']?.toString()] ?? '',
            variantName: v['name']?.toString() ?? '',
          )).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load variants: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load variants: $e');
    }
  }

  @override
  Future<List<({String id, String name})>> getCategoriesForAssetType({
    required String assetType,
  }) async {
    try {
      final domainRows = await _client
          .schema('core')
          .from('domains')
          .select('id, name');
      final normalized = assetType.trim().toLowerCase();
      final candidates = <String>{normalized, '${normalized}s'};
      final matchingDomainId = (domainRows as List)
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (row) => candidates.contains((row['name']?.toString() ?? '').trim().toLowerCase()),
            orElse: () => const <String, dynamic>{},
          )['id']?.toString();
      if (matchingDomainId == null || matchingDomainId.isEmpty) {
        return const [];
      }
      final rows = await _client
          .schema('core')
          .from('categories')
          .select('id, name')
          .eq('domain_id', matchingDomainId)
          .order('name', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map((r) => (
                id: r['id']?.toString() ?? '',
                name: r['name']?.toString() ?? '',
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load taxonomy categories: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load taxonomy categories: $e');
    }
  }

  @override
  Future<List<({String id, String categoryId, String name})>> getItemsForCategory({
    required String categoryId,
  }) async {
    try {
      final rows = await _client
          .schema('core')
          .from('items')
          .select('id, category_id, name')
          .eq('category_id', categoryId)
          .order('name', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map((r) => (
                id: r['id']?.toString() ?? '',
                categoryId: r['category_id']?.toString() ?? '',
                name: r['name']?.toString() ?? '',
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load taxonomy items: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load taxonomy items: $e');
    }
  }

  @override
  Future<List<({String id, String itemName, String variantName})>> getVariantsForItem({
    required String itemId,
  }) async {
    try {
      final variantRows = await _client
          .schema('core')
          .from('item_variants')
          .select('id, item_id, name')
          .eq('item_id', itemId)
          .order('name', ascending: true);
      final variants = (variantRows as List).cast<Map<String, dynamic>>();
      final itemRows = await _client
          .schema('core')
          .from('items')
          .select('id, name')
          .inFilter('id', [itemId]);
      final items = <String, String>{};
      for (final row in (itemRows as List).cast<Map<String, dynamic>>()) {
        items[row['id'].toString()] = row['name']?.toString() ?? '';
      }
      return variants.map((v) => (
            id: v['id']?.toString() ?? '',
            itemName: items[v['item_id']?.toString()] ?? '',
            variantName: v['name']?.toString() ?? '',
          )).toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load taxonomy variants: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load taxonomy variants: $e');
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
  Future<Map<String, String>> getActivityTypeNames() async {
    try {
      final rows = await _client
          .schema('farm_management')
          .from('activity_types')
          .select('id, name');
      return {
        for (final row in (rows as List).cast<Map<String, dynamic>>())
          row['id'].toString(): row['name']?.toString() ?? '',
      };
    } on PostgrestException catch (e) {
      throw Exception('Failed to load activity types: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load activity types: $e');
    }
  }

  static final RegExp _uuidPattern =
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  bool _isUuid(String value) => _uuidPattern.hasMatch(value);

  /// Resolves a symbolic activity-type key (e.g. 'maize_planting',
  /// 'general', template name) to a real farm_management.activity_types.id.
  /// Real UUIDs pass through unchanged. Throws when no match exists so the
  /// caller surfaces a clean error instead of silently failing.
  Future<String> _resolveActivityTypeId(String value) async {
    if (_isUuid(value)) return value;
    final key = value.trim().toLowerCase();
    final response = await _client
        .schema('farm_management')
        .from('activity_types')
        .select('id, name');
    final types = (response as List).cast<Map<String, dynamic>>();
    String? byName;
    String? byContains;
    for (final t in types) {
      final name = (t['name']?.toString() ?? '').toLowerCase();
      if (name == key) {
        byName = t['id'].toString();
        break;
      }
      if (name.contains(key) || key.contains(name)) {
        byContains ??= t['id'].toString();
      }
    }
    final resolved = byName ?? byContains;
    if (resolved == null) {
      throw Exception('Unknown activity type: $value');
    }
    return resolved;
  }

  @override
  Future<ActivityModel> createActivity({required ActivityModel activity}) async {
    try {
      // Authoritative contract: activities attach to an ASSET (the
      // crop/livestock instance). farm/field/crop ids are NOT activity
      // table columns.
      if (activity.assetId == null) {
        throw Exception('An asset (crop/livestock) must be selected to create an activity.');
      }
      final activityTypeId = await _resolveActivityTypeId(activity.activityTypeId);

      final payload = <String, dynamic>{
        'asset_id': activity.assetId,
        'activity_type_id': activityTypeId,
        'performed_at': activity.performedAt.toIso8601String(),
        'notes': activity.notes,
        if (activity.planId != null) 'plan_id': activity.planId,
      };

      final response = await _client
          .schema('farm_management')
          .rpc('create_activity', params: {'activity_data': payload});

      // RPC returns a SCALAR UUID — use the returned value directly.
      final activityId = response?.toString().trim();
      if (activityId == null || activityId.isEmpty || activityId == 'null') {
        throw Exception('Activity RPC returned no activity id');
      }

      // Persist attribute values if present (activity_values table).
      if (activity.attributeValues.isNotEmpty) {
        for (final entry in activity.attributeValues.entries) {
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
      }

      return ActivityModel(
        id: activityId,
        activityTypeId: activityTypeId,
        farmId: activity.farmId,
        fieldId: activity.fieldId,
        cropOrLivestockId: activity.cropOrLivestockId,
        cropOrLivestockType: activity.cropOrLivestockType,
        performedAt: activity.performedAt,
        notes: activity.notes,
        assetId: activity.assetId,
        planId: activity.planId,
        attributeValues: activity.attributeValues,
      );
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
          .schema('farm_management').from('assets')
          .select('id, entity_id, farm_id, asset_type, variant_id, field_id, '
              'status, quantity, unit_id, metadata, created_at')
          .eq('id', cropId)
          .eq('farm_id', farmId)
          .eq('asset_type', 'crop')
          .maybeSingle();
      if (response == null) return null;
      final labels = await _fetchVariantLabels({response['variant_id']?.toString() ?? ''});
      return _cropFromAssetRow(response, labels);
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