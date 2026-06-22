// ============================================================
// STOCK MUTATION ENGINE
// ============================================================
//
// 🧠 SECTION 5 — INVENTORY & STOCK ENGINE
///
/// PURPOSE:
/// Provides stock movement operations that persist into the
/// existing schema tables:
///   - activity_stock_rules (direction rules)
///   - production_records (production inflow)
///   - assets (quantity tracking)
///   - farm_inputs (consumption tracking)
///
/// FLOW EXAMPLES:
///   FEEDING ACTIVITY → reduce feed stock
///   HARVEST ACTIVITY → increase production inventory
///   MARKETPLACE SALE → reduce available stock
///
/// PATTERN:
///   Extends existing farm repository
///   Uses existing Supabase client via repository
///   No duplicate stock systems
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/events/app_event_bus.dart';
import 'package:famhub_app/core/events/events.dart';
import 'package:famhub_app/core/events/workflow_events.dart';

/// Direction of stock movement
enum StockDirection {
  /// Stock flows INTO inventory (production, purchase)
  inflow,

  /// Stock flows OUT OF inventory (consumption, sale)
  outflow,

  /// Stock is adjusted (correction, loss)
  adjustment,
}

/// Result of a stock mutation operation
class StockMutationResult {
  final String assetId;
  final StockDirection direction;
  final double quantity;
  final double newBalance;
  final bool success;
  final String? errorMessage;

  const StockMutationResult({
    required this.assetId,
    required this.direction,
    required this.quantity,
    required this.newBalance,
    required this.success,
    this.errorMessage,
  });
}

/// Stock movement record for persistence
class StockMovement {
  final String? id;
  final String farmId;
  final String? assetId;
  final String? activityId;
  final StockDirection direction;
  final double quantity;
  final String? unitId;
  final String? description;
  final DateTime timestamp;

  const StockMovement({
    this.id,
    required this.farmId,
    this.assetId,
    this.activityId,
    required this.direction,
    required this.quantity,
    this.unitId,
    this.description,
    required this.timestamp,
  });
}

/// ============================================================
/// STOCK MUTATION ENGINE
/// ============================================================
///
/// Central engine for all inventory mutations.
/// Every mutation:
///   1. Validates stock availability (for outflows)
///   2. Updates asset quantity
///   3. Records in production_records (for inflow)
///   4. Emits telemetry events
/// ============================================================
class StockMutationEngine {
  final SupabaseClient _client;
  final AppEventBus _eventBus;

  StockMutationEngine({
    SupabaseClient? client,
    AppEventBus? eventBus,
  })  : _client = client ?? Supabase.instance.client,
        _eventBus = eventBus ?? AppEventBus.instance;

  /// ============================================================
  /// CONSUME STOCK (OUTFLOW)
  /// ============================================================
  ///
  /// Reduces stock for an asset. Used for:
  /// - Feeding activities (reduce feed)
  /// - Input usage (reduce fertilizer/seed stock)
  /// - Marketplace sales (reduce product stock)
  ///
  /// Returns StockMutationResult with new balance.
  /// Throws if insufficient stock.
  /// ============================================================
  Future<StockMutationResult> consumeStock({
    required String farmId,
    required String assetId,
    required double quantity,
    String? activityId,
    String? unitId,
    String? description,
  }) async {
    try {
      // Step 1: Check current stock
      final currentAsset = await _client
          .from('assets')
          .select('id, quantity, asset_name')
          .eq('id', assetId)
          .eq('farm_id', farmId)
          .single();

      final currentQty = (currentAsset['quantity'] as num?)?.toDouble() ?? 0;

      // Step 2: Validate availability
      if (currentQty < quantity) {
        _emitInventoryFailure(
          assetId: assetId,
          farmId: farmId,
          reason: 'Insufficient stock: $currentQty < $quantity',
        );
        return StockMutationResult(
          assetId: assetId,
          direction: StockDirection.outflow,
          quantity: quantity,
          newBalance: currentQty,
          success: false,
          errorMessage: 'Insufficient stock. Available: $currentQty, Requested: $quantity',
        );
      }

      // Step 3: Update asset quantity
      final newBalance = currentQty - quantity;
      await _client
          .from('assets')
          .update({'quantity': newBalance, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', assetId);

      // Step 4: Record consumption as production record (negative quantity = outflow)
      if (activityId != null) {
        await _client.from('production_records').insert({
          'farm_id': farmId,
          'asset_id': assetId,
          'activity_id': activityId,
          'quantity': -quantity,
          'unit_id': unitId,
          'source_type': 'stock_mutation',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Step 5: Emit telemetry
      _emitStockEvent(
        farmId: farmId,
        assetId: assetId,
        direction: StockDirection.outflow,
        quantity: quantity,
        newBalance: newBalance,
        activityId: activityId,
      );

      return StockMutationResult(
        assetId: assetId,
        direction: StockDirection.outflow,
        quantity: quantity,
        newBalance: newBalance,
        success: true,
      );
    } catch (e) {
      _emitInventoryFailure(
        assetId: assetId,
        farmId: farmId,
        reason: e.toString(),
      );
      return StockMutationResult(
        assetId: assetId,
        direction: StockDirection.outflow,
        quantity: quantity,
        newBalance: 0,
        success: false,
        errorMessage: 'Stock consumption failed: $e',
      );
    }
  }

  /// ============================================================
  /// ADD STOCK (INFLOW)
  /// ============================================================
  ///
  /// Increases stock for an asset. Used for:
  /// - Harvest activities (increase crop stock)
  /// - Milk production (increase dairy stock)
  /// - Egg collection (increase poultry stock)
  /// - Purchase of inputs
  /// ============================================================
  Future<StockMutationResult> addStock({
    required String farmId,
    required String assetId,
    required double quantity,
    String? activityId,
    String? unitId,
    String? description,
  }) async {
    try {
      // Step 1: Get current stock
      final currentAsset = await _client
          .from('assets')
          .select('id, quantity, asset_name')
          .eq('id', assetId)
          .eq('farm_id', farmId)
          .single();

      final currentQty = (currentAsset['quantity'] as num?)?.toDouble() ?? 0;

      // Step 2: Update asset quantity
      final newBalance = currentQty + quantity;
      await _client
          .from('assets')
          .update({'quantity': newBalance, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', assetId);

      // Step 3: Record production inflow
      if (activityId != null) {
        await _client.from('production_records').insert({
          'farm_id': farmId,
          'asset_id': assetId,
          'activity_id': activityId,
          'quantity': quantity,
          'unit_id': unitId,
          'source_type': 'harvest',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Step 4: Emit telemetry
      _emitStockEvent(
        farmId: farmId,
        assetId: assetId,
        direction: StockDirection.inflow,
        quantity: quantity,
        newBalance: newBalance,
        activityId: activityId,
      );

      return StockMutationResult(
        assetId: assetId,
        direction: StockDirection.inflow,
        quantity: quantity,
        newBalance: newBalance,
        success: true,
      );
    } catch (e) {
      _emitInventoryFailure(
        assetId: assetId,
        farmId: farmId,
        reason: e.toString(),
      );
      return StockMutationResult(
        assetId: assetId,
        direction: StockDirection.inflow,
        quantity: quantity,
        newBalance: 0,
        success: false,
        errorMessage: 'Stock addition failed: $e',
      );
    }
  }

  /// ============================================================
  /// GET STOCK RULES FOR ACTIVITY TYPE
  /// ============================================================
  ///
  /// Loads stock rules from activity_stock_rules table.
  /// Determines if activity consumes or produces stock.
  /// ============================================================
  Future<List<Map<String, dynamic>>> getStockRulesForActivityType({
    required String activityTypeId,
  }) async {
    try {
      final rules = await _client
          .from('activity_stock_rules')
          .select()
          .eq('activity_type_id', activityTypeId);

      return (rules as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// ============================================================
  /// GET AVAILABLE STOCK (MARKETPLACE READY)
  /// ============================================================
  ///
  /// Computes available (unreserved) stock for marketplace listings.
  /// ============================================================
  Future<Map<String, double>> getAvailableStock({required String farmId}) async {
    try {
      // Get all assets with quantity > 0
      final assets = await _client
          .from('assets')
          .select('id, asset_name, quantity')
          .eq('farm_id', farmId)
          .gt('quantity', 0);

      final result = <String, double>{};
      for (final asset in (assets as List).cast<Map<String, dynamic>>()) {
        final id = asset['id'] as String;
        final qty = (asset['quantity'] as num?)?.toDouble() ?? 0;
        result[id] = qty;
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  /// ============================================================
  /// ADJUST STOCK (CORRECTION)
  /// ============================================================
  ///
  /// Manual stock adjustment for inventory corrections.
  /// ============================================================
  Future<StockMutationResult> adjustStock({
    required String farmId,
    required String assetId,
    required double newQuantity,
    String? reason,
  }) async {
    try {
      await _client
          .from('assets')
          .update({'quantity': newQuantity, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', assetId);

      _eventBus.emit(WorkflowEvent(
        workflowName: 'stock_adjustment',
        stepName: 'adjust',
        status: WorkflowStepStatus.completed,
        payload: {
          'asset_id': assetId,
          'new_quantity': newQuantity,
          'reason': reason ?? 'manual adjustment',
        },
      ));

      return StockMutationResult(
        assetId: assetId,
        direction: StockDirection.adjustment,
        quantity: newQuantity,
        newBalance: newQuantity,
        success: true,
      );
    } catch (e) {
      return StockMutationResult(
        assetId: assetId,
        direction: StockDirection.adjustment,
        quantity: 0,
        newBalance: 0,
        success: false,
        errorMessage: 'Stock adjustment failed: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TELEMETRY EMITTERS
  // ═══════════════════════════════════════════════════════════════

  void _emitStockEvent({
    required String farmId,
    required String assetId,
    required StockDirection direction,
    required double quantity,
    required double newBalance,
    String? activityId,
  }) {
    _eventBus.emit(WorkflowEvent(
      workflowName: 'stock_mutation',
      stepName: direction == StockDirection.inflow ? 'inflow' : 'outflow',
      status: WorkflowStepStatus.completed,
      payload: {
        'farm_id': farmId,
        'asset_id': assetId,
        'activity_id': activityId,
        'quantity': quantity,
        'new_balance': newBalance,
        'direction': direction.name,
      },
    ));
  }

  void _emitInventoryFailure({
    required String assetId,
    required String farmId,
    required String reason,
  }) {
    _eventBus.emit(WorkflowEvent.failed(
      workflowName: 'stock_mutation',
      stepName: 'validate',
      error: reason,
    ));
  }
}
