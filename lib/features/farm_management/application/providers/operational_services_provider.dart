// ignore: dangling_library_doc_comments
/// ============================================================
/// OPERATIONAL SERVICES PROVIDER
/// ============================================================
///
/// Provides instances of the operational services that power
/// the REAL DATA operationalization:
///   - StockMutationEngine (inventory management)
///   - KpiAutomationService (KPI updates)
///   - FinancialRecordingService (financial tracking)
///
/// These services share a SupabaseClient instance and are
/// available throughout the app via Riverpod.
/// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/farm_management/infrastructure/services/stock_mutation_engine.dart';
import 'package:famhub_app/features/farm_management/infrastructure/services/kpi_automation_service.dart';
import 'package:famhub_app/features/farm_management/infrastructure/services/financial_recording_service.dart';

/// Supabase client provider (resolves the singleton instance)
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Stock Mutation Engine provider
final stockMutationEngineProvider = Provider<StockMutationEngine>((ref) {
  return StockMutationEngine();
});

/// KPI Automation Service provider
final kpiAutomationServiceProvider = Provider<KpiAutomationService>((ref) {
  return KpiAutomationService();
});

/// Financial Recording Service provider
final financialRecordingServiceProvider = Provider<FinancialRecordingService>((ref) {
  return FinancialRecordingService();
});
