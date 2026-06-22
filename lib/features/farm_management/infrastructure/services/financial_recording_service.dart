// ============================================================
// FINANCIAL RECORDING SERVICE
// ============================================================
//
// 🧠 SECTION 5 — FINANCIAL TRACKING
///
/// PURPOSE:
/// Persists financial records for activities and production events.
/// Each financial record links back to the original activity/production
/// and automatically triggers KPI updates.
///
/// SCHEMA:
///   farm_management.financial_records:
///     - id (uuid)
///     - farm_id (uuid)
///     - activity_id (uuid, nullable)
///     - record_type (text): income, expense, sale
///     - amount (numeric)
///     - description (text)
///     - recorded_at (timestamptz)
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/events/app_event_bus.dart';
import 'package:famhub_app/core/events/workflow_events.dart';

class FinancialRecordingService {
  final SupabaseClient _client;
  final AppEventBus _eventBus;

  FinancialRecordingService({
    SupabaseClient? client,
    AppEventBus? eventBus,
  })  : _client = client ?? Supabase.instance.client,
        _eventBus = eventBus ?? AppEventBus.instance;

  /// ============================================================
  /// RECORD EXPENSE
  /// ============================================================
  ///
  /// Records a financial expense, optionally linked to an activity or production.
  /// Automatically triggers KPI update.
  /// ============================================================
  Future<Map<String, dynamic>> recordExpense({
    required String farmId,
    required double amount,
    required String description,
    String? activityId,
    String? category,
  }) async {
    return _recordFinancial(
      farmId: farmId,
      recordType: 'expense',
      amount: -amount.abs(), // Expenses are negative
      description: description,
      activityId: activityId,
      category: category,
    );
  }

  /// ============================================================
  /// RECORD INCOME
  /// ============================================================
  ///
  /// Records financial income from production or other sources.
  /// ============================================================
  Future<Map<String, dynamic>> recordIncome({
    required String farmId,
    required double amount,
    required String description,
    String? activityId,
    String? category,
  }) async {
    return _recordFinancial(
      farmId: farmId,
      recordType: 'income',
      amount: amount.abs(),
      description: description,
      activityId: activityId,
      category: category,
    );
  }

  /// ============================================================
  /// RECORD SALE
  /// ============================================================
  ///
  /// Records a marketplace sale transaction.
  /// ============================================================
  Future<Map<String, dynamic>> recordSale({
    required String farmId,
    required double amount,
    required String description,
    String? activityId,
    String? listingId,
  }) async {
    return _recordFinancial(
      farmId: farmId,
      recordType: 'sale',
      amount: amount.abs(),
      description: description,
      activityId: activityId,
      category: 'marketplace',
      metadata: listingId != null ? {'listing_id': listingId} : null,
    );
  }

  /// ============================================================
  /// INTERNAL RECORD METHOD
  /// ============================================================
  Future<Map<String, dynamic>> _recordFinancial({
    required String farmId,
    required String recordType,
    required double amount,
    required String description,
    String? activityId,
    String? category,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final record = {
        'farm_id': farmId,
        'activity_id': activityId,
        'record_type': recordType,
        'amount': amount,
        'description': description,
        'recorded_at': DateTime.now().toIso8601String(),
        if (category != null) 'category': category,
      };

      await _client.from('financial_records').insert(record);

      _eventBus.emit(WorkflowEvent.completed(
        workflowName: 'financial_recording',
        stepName: 'record_$recordType',
        payload: {
          'farm_id': farmId,
          'amount': amount,
          'record_type': recordType,
          'activity_id': activityId,
        },
      ));

      return {...record, 'success': true};
    } catch (e) {
      _eventBus.emit(WorkflowEvent.failed(
        workflowName: 'financial_recording',
        stepName: 'record_$recordType',
        error: e.toString(),
      ));
      return {'success': false, 'error': e.toString()};
    }
  }
}
