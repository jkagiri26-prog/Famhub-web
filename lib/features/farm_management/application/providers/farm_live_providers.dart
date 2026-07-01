/// ============================================================
/// FARM LIVE PROVIDERS
/// ============================================================
///
/// Phase D: Every widget fetches its own data from production providers.
/// Architecture:
///   DashboardWidgetDescriptor -> WidgetBuilderRegistry -> LiveProvider -> Repository -> Supabase
///
///   - Is self-contained (fetches its own data)
///   - Reports execution metrics to observability
///   - Handles errors gracefully with fallback states
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/models/farm_dashboard_summary.dart';
import 'package:famhub_app/features/farm_management/domain/models/activity_model.dart';
import 'package:famhub_app/features/farm_management/domain/entities/crop_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/livestock_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/asset_entity.dart';
import 'package:famhub_app/features/farm_management/domain/entities/production_entity.dart';
import 'package:famhub_app/features/farm_management/domain/repositories/farm_repository.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_repository_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_context_provider.dart';

/// ============================================================
/// PROVIDER: FARM KPI DATA (LIVE)
/// ============================================================
///
/// Feeds the farm_kpis dashboard widget with real Supabase data.
/// Refreshes when farm context changes.
/// ============================================================
final farmKpiDataProvider = FutureProvider<FarmDashboardSummary>((ref) async {
  final stopwatch = Stopwatch()..start();
  try {
    final farmId = ref.watch(farmContextProvider).farmId;
    if (farmId == null) {
      return const FarmDashboardSummary(
        totalProduction: 0,
        totalSales: 0,
        totalExpenses: 0,
        totalYield: 0,
        stockValue: 0,
      );
    }

    final repository = ref.read(farmRepositoryProvider);
    final summary = await repository.getDashboardSummary(farmId: farmId);

    _reportProviderExecution('farm_kpis', stopwatch.elapsedMilliseconds, null);

    return summary;
  } catch (e) {
    _reportProviderExecution('farm_kpis', stopwatch.elapsedMilliseconds, e.toString());
    rethrow;
  }
});

/// ============================================================
/// PROVIDER: FARM TODAY ACTIVITIES (LIVE)
/// ============================================================
///
/// Feeds the farm_activity_timeline dashboard widget.
/// ============================================================
final farmTodayActivitiesProvider = FutureProvider<List<ActivityModel>>((ref) async {
  final stopwatch = Stopwatch()..start();
  try {
    final farmId = ref.watch(farmContextProvider).farmId;
    if (farmId == null) return [];

    final repository = ref.read(farmRepositoryProvider);
    final activities = await repository.getTodayActivities(farmId: farmId);

    _reportProviderExecution('farm_activity_timeline', stopwatch.elapsedMilliseconds, null);
    return activities;
  } catch (e) {
    _reportProviderExecution('farm_activity_timeline', stopwatch.elapsedMilliseconds, e.toString());
    rethrow;
  }
});

/// ============================================================
/// PROVIDER: FARM PRODUCTION RECORDS (LIVE)
/// ============================================================
///
/// Feeds the farm_production_summary dashboard widget.
/// ============================================================
final farmProductionRecordsProvider = FutureProvider<List<ProductionEntity>>((ref) async {
  final stopwatch = Stopwatch()..start();
  try {
    final farmId = ref.watch(farmContextProvider).farmId;
    if (farmId == null) return [];

    final repository = ref.read(farmRepositoryProvider);
    final records = await repository.getProductionRecords(farmId: farmId);

    _reportProviderExecution('farm_production_summary', stopwatch.elapsedMilliseconds, null);
    return records;
  } catch (e) {
    _reportProviderExecution('farm_production_summary', stopwatch.elapsedMilliseconds, e.toString());
    rethrow;
  }
});

/// ============================================================
/// PROVIDER: FARM CROPS (LIVE)
/// ============================================================
///
/// Feeds farm crops dashboard widgets.
/// ============================================================
final farmCropsProvider = FutureProvider<List<CropEntity>>((ref) async {
  final stopwatch = Stopwatch()..start();
  try {
    final farmId = ref.watch(farmContextProvider).farmId;
    if (farmId == null) return [];

    final repository = ref.read(farmRepositoryProvider);
    final crops = await repository.getCrops(farmId: farmId);

    _reportProviderExecution('farm_crops', stopwatch.elapsedMilliseconds, null);
    return crops;
  } catch (e) {
    _reportProviderExecution('farm_crops', stopwatch.elapsedMilliseconds, e.toString());
    rethrow;
  }
});

/// ============================================================
/// PROVIDER: FARM LIVESTOCK (LIVE)
/// ============================================================
///
/// Feeds farm_livestock dashboard widgets.
/// ============================================================
final farmLivestockProvider = FutureProvider<List<LivestockEntity>>((ref) async {
  final stopwatch = Stopwatch()..start();
  try {
    final farmId = ref.watch(farmContextProvider).farmId;
    if (farmId == null) return [];

    final repository = ref.read(farmRepositoryProvider);
    final livestock = await repository.getLivestock(farmId: farmId);

    _reportProviderExecution('farm_livestock', stopwatch.elapsedMilliseconds, null);
    return livestock;
  } catch (e) {
    _reportProviderExecution('farm_livestock', stopwatch.elapsedMilliseconds, e.toString());
    rethrow;
  }
});

/// ============================================================
/// PROVIDER: FARM ASSETS (LIVE)
/// ============================================================
///
/// Feeds farm_assets dashboard widgets.
/// ============================================================
final farmAssetsProvider = FutureProvider<List<AssetEntity>>((ref) async {
  final stopwatch = Stopwatch()..start();
  try {
    final farmId = ref.watch(farmContextProvider).farmId;
    if (farmId == null) return [];

    final repository = ref.read(farmRepositoryProvider);
    final assets = await repository.getAssets(farmId: farmId);

    _reportProviderExecution('farm_assets', stopwatch.elapsedMilliseconds, null);
    return assets;
  } catch (e) {
    _reportProviderExecution('farm_assets', stopwatch.elapsedMilliseconds, e.toString());
    rethrow;
  }
});

/// ============================================================
/// PROVIDER: FARM STOCK VALUE (LIVE)
/// ============================================================
///
/// Feeds farm_stock_summary dashboard widget.
/// ============================================================
final farmStockValueProvider = FutureProvider<Map<String, double>>((ref) async {
  final stopwatch = Stopwatch()..start();
  try {
    final farmId = ref.watch(farmContextProvider).farmId;
    if (farmId == null) return {};

    final repository = ref.read(farmRepositoryProvider);
    final stock = await repository.getAvailableStock(farmId: farmId);

    _reportProviderExecution('farm_stock_summary', stopwatch.elapsedMilliseconds, null);
    return stock;
  } catch (e) {
    _reportProviderExecution('farm_stock_summary', stopwatch.elapsedMilliseconds, e.toString());
    rethrow;
  }
});

/// ============================================================
/// PROVIDER: FARM USER FARMS (LIVE)
/// ============================================================
final farmUserFarmsProvider = FutureProvider<List>((ref) async {
  final stopwatch = Stopwatch()..start();
  try {
    final repository = ref.read(farmRepositoryProvider);
    final farms = await repository.getUserFarms();

    _reportProviderExecution('farm_selector', stopwatch.elapsedMilliseconds, null);
    return farms;
  } catch (e) {
    _reportProviderExecution('farm_selector', stopwatch.elapsedMilliseconds, e.toString());
    rethrow;
  }
});

/// ============================================================
/// PROVIDER: FARM ALERTS (LIVE)
/// ============================================================
///
/// Computes alerts from live farm data.
/// ============================================================
final farmAlertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final stopwatch = Stopwatch()..start();
  try {
    final farmId = ref.watch(farmContextProvider).farmId;
    if (farmId == null) return [];

    final repository = ref.read(farmRepositoryProvider);
    final alerts = <Map<String, dynamic>>[];

    // Dashboard summary alert
    try {
      final summary = await repository.getDashboardSummary(farmId: farmId);
      if (summary.stockValue < 100) {
        alerts.add({
          'type': 'warning',
          'message': 'Low stock value detected (\$${summary.stockValue})',
          'severity': 'medium',
        });
      }
    } catch (_) {
      // Non-critical
    }

    // Harvest reminders from crops
    try {
      final crops = await repository.getCrops(farmId: farmId);
      for (final crop in crops) {
        if (crop.expectedHarvestDate != null &&
            crop.expectedHarvestDate!.difference(DateTime.now()).inDays <= 7 &&
            crop.expectedHarvestDate!.difference(DateTime.now()).inDays >= 0) {
          alerts.add({
            'type': 'info',
            'message': 'Harvest approaching: ${crop.cropName} (${crop.expectedHarvestDate!.toLocal().toString().split(' ')[0]})',
            'severity': 'high',
          });
        }
      }
    } catch (_) {
      // Non-critical
    }

    _reportProviderExecution('farm_alerts', stopwatch.elapsedMilliseconds, null);
    return alerts;
  } catch (e) {
    _reportProviderExecution('farm_alerts', stopwatch.elapsedMilliseconds, e.toString());
    rethrow;
  }
});

/// ============================================================
/// OBSERVABILITY HELPER
/// ============================================================
///
/// Reports provider execution metrics through the existing
/// observability layer. Non-blocking, never throws.
/// ============================================================
void _reportProviderExecution(
  String providerKey,
  int durationMs,
  String? error,
) {
  try {
    // Use the existing observability infrastructure.
    // This is a lightweight instrumentation point.
    // ignore: avoid_print
    print('[PhaseD:Provider] $providerKey completed in ${durationMs}ms'
        '${error != null ? ' ERROR: $error' : ''}');
  } catch (_) {
    // Never let observability fail the provider
  }
}
