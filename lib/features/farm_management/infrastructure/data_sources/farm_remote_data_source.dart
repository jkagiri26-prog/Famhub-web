/// ============================================================
/// FARM REMOTE DATA SOURCE
/// ============================================================
///
/// Abstraction over Supabase for farm management data operations.
/// FarmRepositoryImpl delegates to this data source.
/// Can be swapped for testing/mock implementations.
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Remote data source for farm management operations.
/// Encapsulates all Supabase queries for the farm module.
class FarmRemoteDataSource {
  final SupabaseClient _client;

  FarmRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  SupabaseClient get client => _client;

  // ── Dashboard ──

  Future<Map<String, dynamic>?> fetchFarmKpis(String farmId) async {
    try {
      return await _client
          .schema('farm_management').from('farm_kpis')
          .select()
          .eq('farm_id', farmId)
          .single() as Map<String, dynamic>?;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null;
      rethrow;
    }
  }

        Future<List<Map<String, dynamic>>> fetchActivitiesWithJoins({
          required DateTime? since,
          int limit = 50,
        }) async {
          var query = _client
              .schema('farm_management').from('activities')
              .select('''
                id, activity_type_id, performed_at, notes, asset_id, plan_id,
                asset:asset_id(farm_id),
                plan:plan_id(farm_id)
              ''');

          if (since != null) {
            query = query.gte('performed_at', since.toIso8601String());
          }

          final response = await query
              .order('performed_at', ascending: false)
              .limit(limit);
          return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchFarms() async {
    return (await _client
        .schema('farm_management').from('farms')
        .select()
        .eq('is_active', true)
        .order('farm_name', ascending: true)).cast<Map<String, dynamic>>();
  }

  // ── Crops ──

  Future<List<Map<String, dynamic>>> fetchCrops(String farmId) async {
    return (await _client
        .schema('farm_management').from('crops')
        .select()
        .eq('farm_id', farmId)
        .order('created_at', ascending: false)).cast<Map<String, dynamic>>();
  }

  Future<void> insertCrop(Map<String, dynamic> data) async {
    await _client.schema('farm_management').from('crops').insert(data);
  }

  // ── Livestock ──

  Future<List<Map<String, dynamic>>> fetchLivestock(String farmId) async {
    return (await _client
        .schema('farm_management').from('livestock')
        .select()
        .eq('farm_id', farmId)
        .order('created_at', ascending: false)).cast<Map<String, dynamic>>();
  }

  Future<void> insertLivestock(Map<String, dynamic> data) async {
    await _client.schema('farm_management').from('livestock').insert(data);
  }

  // ── Assets ──

  Future<List<Map<String, dynamic>>> fetchAssets(String farmId) async {
    return (await _client
        .schema('farm_management').from('assets')
        .select()
        .eq('farm_id', farmId)
        .order('created_at', ascending: false)).cast<Map<String, dynamic>>();
  }

  Future<void> insertAsset(Map<String, dynamic> data) async {
    await _client.schema('farm_management').from('assets').insert(data);
  }

  // ── Fields ──

  Future<List<Map<String, dynamic>>> fetchFields(String farmId) async {
    return (await _client
        .schema('farm_management').from('fields')
        .select()
        .eq('farm_id', farmId)
        .order('name', ascending: true)).cast<Map<String, dynamic>>();
  }

  // ── Production ──

  Future<List<Map<String, dynamic>>> fetchProductionRecords(String farmId, {int limit = 100}) async {
    return (await _client
        .schema('farm_management').from('production_records')
        .select()
        .eq('farm_id', farmId)
        .order('created_at', ascending: false)
        .limit(limit)).cast<Map<String, dynamic>>();
  }

  Future<void> insertProductionRecord(Map<String, dynamic> data) async {
    await _client.schema('farm_management').from('production_records').insert(data);
  }

  // ── Activities ──

  Future<Map<String, dynamic>> insertActivity(Map<String, dynamic> data) async {
    return (await _client.schema('farm_management').from('activities').insert(data).select('id').single());
  }

  Future<void> insertActivityValue(Map<String, dynamic> data) async {
    await _client.schema('farm_management').from('activity_values').insert(data);
  }

  Future<Map<String, dynamic>?> fetchAsset(String assetId, String farmId) async {
    return await _client
        .schema('farm_management').from('assets')
        .select('id, quantity')
        .eq('id', assetId)
        .eq('farm_id', farmId)
        .maybeSingle();
  }

  Future<void> updateAssetQuantity(String assetId, double quantity) async {
    await _client
        .schema('farm_management').from('assets')
        .update({'quantity': quantity, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', assetId);
  }

  // ── Financial ──

  Future<void> insertFinancialRecord(Map<String, dynamic> data) async {
    await _client.schema('farm_management').from('financial_records').insert(data);
  }

  Future<List<Map<String, dynamic>>> fetchFinancialRecords(String farmId) async {
    return (await _client
        .schema('farm_management').from('financial_records')
        .select('record_type, amount')
        .eq('farm_id', farmId)).cast<Map<String, dynamic>>();
  }

  // ── Marketplace Sync ──

  Future<void> insertFarmReport(Map<String, dynamic> data) async {
    await _client.schema('farm_management').from('farm_reports').insert(data);
  }

  // ── KPI ──

  Future<void> upsertFarmKpi(Map<String, dynamic> data) async {
    await _client.schema('farm_management').from('farm_kpis').upsert(data, onConflict: 'farm_id');
  }

  Future<void> upsertFarmAggregate(Map<String, dynamic> data) async {
    await _client.schema('farm_management').from('farm_aggregates').upsert(data, onConflict: 'farm_id');
  }
}
