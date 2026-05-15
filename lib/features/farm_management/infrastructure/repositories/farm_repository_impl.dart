import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/activity_model.dart';
import '../../domain/models/farm_dashboard_summary.dart';
import '../../domain/models/farm_entity.dart';
import '../../domain/models/production_model.dart';
import '../../domain/repositories/farm_repository.dart';

/// Supabase-backed implementation of FarmRepository.
///
/// Architecture:
/// - Uses RLS for entity-level filtering (core.auth_user_id() server-side)
/// - Never passes user_id from frontend
/// - Queries are scoped to farm_id context
/// - Server-side aggregations via farm_kpis table
///
/// Schema mappings:
/// - getDashboardSummary() → farm_management.farm_kpis
/// - getTodayActivities() → farm_management.activities (time-filtered)
/// - getUserFarms() → farm_management.farms (RLS filtered by entity_id)
/// - recordProduction() → farm_management.production_records
/// - createActivity() → farm_management.activities + activity_values
class FarmRepositoryImpl implements FarmRepository {
  final SupabaseClient _client;

  FarmRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch aggregated KPIs for a farm.
  ///
  /// Maps from: farm_management.farm_kpis
  /// RLS: Protected by farm_id context + entity ownership
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
      if (e.code == 'PGRST116') {
        // No rows found; return zeros
        return const FarmDashboardSummary(
          totalProduction: 0,
          totalSales: 0,
          totalExpenses: 0,
          totalYield: 0,
          stockValue: 0,
        );
      }
      throw Exception('Failed to load dashboard summary: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load dashboard summary: $e');
    }
  }

  /// Fetch activities performed today for a farm.
  ///
  /// Maps from: farm_management.activities filtered via asset.farm_id
  /// Join: activities → assets (via asset_id) → farm_id
  /// Filters: performed_at >= today (00:00:00)
  /// RLS: Protected by entity ownership via asset
  ///
  /// Note: Activities don't have direct farm_id. We filter via:
  /// - asset_id → assets.farm_id
  /// - plan_id → plans.farm_id (alternative path)
  @override
  Future<List<ActivityModel>> getTodayActivities({required String farmId}) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Query activities that belong to this farm's assets or plans
      final response = await _client
          .from('activities')
          .select('''
            id,
            activity_type_id,
            performed_at,
            notes,
            asset_id,
            plan_id,
            asset:asset_id(farm_id),
            plan:plan_id(farm_id)
          ''')
          .gte('performed_at', startOfDay.toIso8601String())
          .order('performed_at', ascending: false)
          .limit(50); // Pagination

      // Filter client-side to ensure farm_id matches
      final List<ActivityModel> activities = [];
      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        final assetFarmId = (row['asset'] as Map<String, dynamic>?)?['farm_id'] as String?;
        final planFarmId = (row['plan'] as Map<String, dynamic>?)?['farm_id'] as String?;

        // Include if asset or plan belongs to this farm
        if (assetFarmId == farmId || planFarmId == farmId) {
          activities.add(ActivityModel(
            id: row['id'] as String,
            activityTypeId: row['activity_type_id'] as String,
            performedAt: DateTime.parse(row['performed_at'] as String),
            notes: row['notes'] as String?,
            assetId: row['asset_id'] as String?,
            planId: row['plan_id'] as String?,
          ));
        }
      }

      return activities;
    } on PostgrestException catch (e) {
      throw Exception('Failed to load today activities: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load today activities: $e');
    }
  }

  /// Fetch all farms accessible to the current user.
  ///
  /// Maps from: farm_management.farms
  /// RLS: Automatically filtered by core.auth_user_id() server-side (entity_id)
  /// Never passes user_id from frontend.
  @override
  Future<List<FarmEntity>> getUserFarms() async {
    try {
      final response = await _client
          .from('farms')
          .select()
          .eq('is_active', true)
          .order('farm_name', ascending: true);

      return (response as List)
          .cast<Map<String, dynamic>>()
          .map((row) => FarmEntity(
                id: row['id'] as String,
                farmName: row['farm_name'] as String,
                description: row['description'] as String?,
                size: (row['size'] as num?)?.toDouble(),
                isActive: row['is_active'] as bool? ?? true,
                isVerified: row['is_verified'] as bool? ?? false,
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Failed to load user farms: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load user farms: $e');
    }
  }

  /// Record production for a farm.
  ///
  /// Inserts into: farm_management.production_records
  /// Fields:
  ///   - farm_id: from context
  ///   - variant_id: from ProductionModel
  ///   - quantity: from ProductionModel
  ///   - unit_id: from ProductionModel (if available)
  ///   - recorded_date: server timestamp
  /// RLS: entity_id set server-side via core.auth_user_id()
  @override
  Future<void> recordProduction({
    required String farmId,
    required ProductionModel production,
  }) async {
    try {
      await _client.from('production_records').insert({
        'farm_id': farmId,
        'variant_id': production.variantId,
        'quantity': production.quantity,
        'unit_id': production.unitId,
        'category_id': production.categoryId,
        'asset_id': production.assetId,
        'field_id': production.fieldId,
        'activity_id': production.activityId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to record production: ${e.message}');
    } catch (e) {
      throw Exception('Failed to record production: $e');
    }
  }

  /// Create a new activity for a farm.
  ///
  /// Inserts into:
  ///   1. farm_management.activities (main record)
  ///   2. farm_management.activity_values (attribute values, if provided)
  /// Note: Activities link to farm via asset_id or plan_id
  /// RLS: entity_id set server-side via core.auth_user_id()
  @override
  Future<void> createActivity({
    required String farmId,
    required ActivityModel activity,
  }) async {
    try {
      // Validate that this activity belongs to the farm context
      // (asset or plan must belong to this farm)
      if (activity.assetId != null) {
        final assetCheck = await _client
            .from('assets')
            .select('id')
            .eq('id', activity.assetId!)
            .eq('farm_id', farmId)
            .maybeSingle();

        if (assetCheck == null) {
          throw Exception('Asset does not belong to the specified farm');
        }
      }

      if (activity.planId != null) {
        final planCheck = await _client
            .from('plans')
            .select('id')
            .eq('id', activity.planId!)
            .eq('farm_id', farmId)
            .maybeSingle();

        if (planCheck == null) {
          throw Exception('Plan does not belong to the specified farm');
        }
      }

      // Insert activity record (entity_id is set server-side)
      await _client.from('activities').insert({
        'activity_type_id': activity.activityTypeId,
        'performed_at': activity.performedAt.toIso8601String(),
        'notes': activity.notes,
        'asset_id': activity.assetId,
        'plan_id': activity.planId,
      });

      // Note: activity_values would be inserted separately if needed.
      // For now, the main activity record is sufficient.
      // Extension point: If attributes are provided on ActivityModel,
      // insert them here via bulk insert.
    } on PostgrestException catch (e) {
      throw Exception('Failed to create activity: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create activity: $e');
    }
  }

  /// Sync farm to marketplace.
  ///
  /// Updates: farm_management.farm_reports
  /// Creates or updates marketplace listing record.
  /// This is typically handled server-side via Edge Functions,
  /// but here we record the sync intent.
  @override
  Future<void> syncMarketplaceListing({required String farmId}) async {
    try {
      await _client.from('farm_reports').insert({
        'farm_id': farmId,
        'report_type': 'marketplace_sync',
        'report_date': DateTime.now(),
        'description': 'Marketplace listing sync initiated from app',
      });
    } on PostgrestException catch (e) {
      throw Exception('Failed to sync marketplace listing: ${e.message}');
    } catch (e) {
      throw Exception('Failed to sync marketplace listing: $e');
    }
  }
}

