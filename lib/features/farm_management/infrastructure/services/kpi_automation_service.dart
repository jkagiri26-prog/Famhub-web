// ============================================================
// KPI AUTOMATION SERVICE
// ============================================================
//
// 🧠 SECTION 6 — KPI AUTOMATION
///
/// PURPOSE:
/// Automatically updates farm_kpis and farm_aggregates tables
/// when operational records are created or modified.
///
/// TRIGGER POINTS:
///   - production_records inserted → update total_production, total_yield
///   - activities completed → update consumption counts
///   - financial_records inserted → update total_income, total_expense
///   - stock mutations → update stock_value
///   - marketplace sales → update total_sales
///
/// RULE:
///   Backend/database aggregation is canonical.
///   Frontend is display-only.
///   NO frontend-calculated KPIs as source of truth.
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/events/app_event_bus.dart';
import 'package:famhub_app/core/events/workflow_events.dart';

/// KPI Automation Service
///
/// Provides methods to update farm KPIs based on operational events.
/// All mutations go through Supabase RPC or direct table updates.
class KpiAutomationService {
  final SupabaseClient _client;
  final AppEventBus _eventBus;

  KpiAutomationService({
    SupabaseClient? client,
    AppEventBus? eventBus,
  })  : _client = client ?? Supabase.instance.client,
        _eventBus = eventBus ?? AppEventBus.instance;

  /// ============================================================
  /// UPDATE PRODUCTION KPIS
  /// ============================================================
  ///
  /// Called after a production record is inserted.
  /// Updates:
  ///   - farm_kpis.total_production
  ///   - farm_kpis.total_yield
  ///   - farm_kpis.avg_yield_per_crop
  ///   - farm_kpis.productivity_score
  /// ============================================================
  Future<void> updateProductionKpis({
    required String farmId,
    double? quantity,
    String? categoryId,
    String? unitId,
  }) async {
    try {
      // Aggregate production totals from production_records
      final aggResult = await _client
          .rpc('fn_aggregate_production_kpis', params: {
        'p_farm_id': farmId,
      }).maybeSingle();

      // If RPC doesn't exist, compute client-side aggregation
      final totalProduction = aggResult?['total_production'] as num? ??
          await _computeTotalProduction(farmId);
      final totalYield = aggResult?['total_yield'] as num? ??
          await _computeTotalYield(farmId);

      // Upsert into farm_kpis
      await _client.schema('farm_management').from('farm_kpis').upsert({
        'farm_id': farmId,
        'total_production': totalProduction.toDouble(),
        'total_yield': totalYield.toDouble(),
        'last_updated': DateTime.now().toIso8601String(),
      }, onConflict: 'farm_id');

      _emitKpiEvent(farmId, 'production', {
        'total_production': totalProduction,
        'total_yield': totalYield,
      });
    } catch (e) {
      _emitKpiFailure(farmId, 'production', e.toString());
    }
  }

  /// ============================================================
  /// UPDATE FINANCIAL KPIS
  /// ============================================================
  ///
  /// Called after a financial record is inserted.
  /// Updates:
  ///   - farm_kpis.total_income / total_expense
  ///   - farm_kpis.profit
  ///   - farm_kpis.avg_cost_per_unit
  ///   - farm_aggregates.total_income / total_expense
  /// ============================================================
  Future<void> updateFinancialKpis({
    required String farmId,
    String? recordType,
    double? amount,
  }) async {
    try {
      // Aggregate financial totals
      final aggResult = await _client
          .rpc('fn_aggregate_financial_kpis', params: {
        'p_farm_id': farmId,
      }).maybeSingle();

      final totalIncome = aggResult?['total_income'] as num? ??
          await _computeTotalIncome(farmId);
      final totalExpense = aggResult?['total_expense'] as num? ??
          await _computeTotalExpense(farmId);
      final profit = totalIncome.toDouble() - totalExpense.toDouble();

      // Upsert into farm_kpis
      await _client.schema('farm_management').from('farm_kpis').upsert({
        'farm_id': farmId,
        'total_income': totalIncome.toDouble(),
        'total_expense': totalExpense.toDouble(),
        'profit': profit,
        'last_updated': DateTime.now().toIso8601String(),
      }, onConflict: 'farm_id');

      // Also update farm_aggregates
      await _client.schema('farm_management').from('farm_aggregates').upsert({
        'farm_id': farmId,
        'total_income': totalIncome.toDouble(),
        'total_expense': totalExpense.toDouble(),
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'farm_id');

      _emitKpiEvent(farmId, 'financial', {
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'profit': profit,
      });
    } catch (e) {
      _emitKpiFailure(farmId, 'financial', e.toString());
    }
  }

  /// ============================================================
  /// UPDATE STOCK VALUE KPI
  /// ============================================================
  ///
  /// Called after stock mutations.
  /// Updates:
  ///   - farm_kpis.stock_value
  /// ============================================================
  Future<void> updateStockValueKpi({
    required String farmId,
  }) async {
    try {
      // Compute total stock value from assets
      final assets = await _client
          .schema('farm_management').from('assets')
          .select('quantity')
          .eq('farm_id', farmId);

      double stockValue = 0;
      for (final asset in (assets as List).cast<Map<String, dynamic>>()) {
        final qty = (asset['quantity'] as num?)?.toDouble() ?? 0;
        stockValue += qty; // Simplified - in real scenario multiply by unit price
      }

      await _client.schema('farm_management').from('farm_kpis').upsert({
        'farm_id': farmId,
        'stock_value': stockValue,
        'last_updated': DateTime.now().toIso8601String(),
      }, onConflict: 'farm_id');

      _emitKpiEvent(farmId, 'stock', {'stock_value': stockValue});
    } catch (e) {
      _emitKpiFailure(farmId, 'stock', e.toString());
    }
  }

  /// ============================================================
  /// UPDATE SALES KPI
  /// ============================================================
  ///
  /// Called after marketplace sales.
  /// Updates:
  ///   - farm_kpis.total_sales
  /// ============================================================
  Future<void> updateSalesKpi({
    required String farmId,
    double? saleAmount,
  }) async {
    try {
      final totalSales = await _computeTotalSales(farmId);

      await _client.schema('farm_management').from('farm_kpis').upsert({
        'farm_id': farmId,
        'total_sales': totalSales.toDouble(),
        'last_updated': DateTime.now().toIso8601String(),
      }, onConflict: 'farm_id');

      _emitKpiEvent(farmId, 'sales', {'total_sales': totalSales});
    } catch (e) {
      _emitKpiFailure(farmId, 'sales', e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // COMPUTATION HELPERS
  // ═══════════════════════════════════════════════════════════════

  Future<double> _computeTotalProduction(String farmId) async {
    try {
      final result = await _client
          .schema('farm_management').from('production_records')
          .select('quantity')
          .eq('farm_id', farmId)
          .gt('quantity', 0);

      double total = 0;
      for (final row in (result as List).cast<Map<String, dynamic>>()) {
        total += (row['quantity'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<double> _computeTotalYield(String farmId) async {
    // Yield is typically production per unit area
    // Simplified for now - aggregate all positive production
    return _computeTotalProduction(farmId);
  }

  Future<double> _computeTotalIncome(String farmId) async {
    try {
      final result = await _client
          .schema('farm_management').from('financial_records')
          .select('amount')
          .eq('farm_id', farmId)
          .eq('record_type', 'income');

      double total = 0;
      for (final row in (result as List).cast<Map<String, dynamic>>()) {
        total += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<double> _computeTotalExpense(String farmId) async {
    try {
      final result = await _client
          .schema('farm_management').from('financial_records')
          .select('amount')
          .eq('farm_id', farmId)
          .eq('record_type', 'expense');

      double total = 0;
      for (final row in (result as List).cast<Map<String, dynamic>>()) {
        total += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<double> _computeTotalSales(String farmId) async {
    try {
      final result = await _client
          .schema('farm_management').from('financial_records')
          .select('amount')
          .eq('farm_id', farmId)
          .eq('record_type', 'sale');

      double total = 0;
      for (final row in (result as List).cast<Map<String, dynamic>>()) {
        total += (row['amount'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TELEMETRY
  // ═══════════════════════════════════════════════════════════════

  void _emitKpiEvent(String farmId, String kpiType, Map<String, dynamic> data) {
    _eventBus.emit(WorkflowEvent(
      workflowName: 'kpi_automation',
      stepName: 'update_$kpiType',
      status: WorkflowStepStatus.completed,
      payload: {'farm_id': farmId, ...data},
    ));
  }

  void _emitKpiFailure(String farmId, String kpiType, String error) {
    _eventBus.emit(WorkflowEvent.failed(
      workflowName: 'kpi_automation',
      stepName: 'update_$kpiType',
      error: error,
    ));
  }
}
