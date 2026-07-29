/// ============================================================
/// FARM LIFECYCLE DETECTOR (Domain Layer)
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Automatically determines the lifecycle stage of a farm
/// from existing data. Users never manually select a stage.
///
/// Detection Logic:
///
///   Created:
///     Farm exists + Main Field exists + No crops + No livestock
///
///   Ready for Production:
///     Farm + Field + Crop or livestock added + No activities
///
///   Production Started:
///     Activities exist + No production records
///
///   Active Management:
///     Multiple activities (>= 3) + Growing production records
///
///   Harvest / Production Complete:
///     Harvest or production records exist
///
///   Reporting & Analysis:
///     Production completed + Reports / aggregated data available
///
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/enums/farm_lifecycle_stage.dart';

/// Input data required for lifecycle detection.
/// All values are derived from existing farm data.
class LifecycleDetectionInput {
  /// Whether the farm has at least one field
  final bool hasField;

  /// Whether the farm has at least one crop
  final bool hasCrop;

  /// Whether the farm has at least one livestock record
  final bool hasLivestock;

  /// Number of activities recorded
  final int activityCount;

  /// Number of production/harvest records
  final int productionRecordCount;

  /// Whether any reports have been generated
  final bool hasReports;

  /// Number of unique activity types performed
  final int uniqueActivityTypes;

  const LifecycleDetectionInput({
    required this.hasField,
    required this.hasCrop,
    required this.hasLivestock,
    required this.activityCount,
    required this.productionRecordCount,
    required this.hasReports,
    this.uniqueActivityTypes = 0,
  });

  /// Whether the farm has any crops or livestock
  bool get hasCropOrLivestock => hasCrop || hasLivestock;
}

/// Domain service that automatically detects a farm's lifecycle stage.
class FarmLifecycleDetector {
  const FarmLifecycleDetector();

  /// Detect the lifecycle stage from farm data.
  ///
  /// This is the single source of truth for stage determination.
  /// All callers use this — no duplicate detection logic anywhere.
  FarmLifecycleStage detect(LifecycleDetectionInput input) {
    // ── Rule 1: Created (brand new farm, nothing added yet) ──
    if (input.hasField && !input.hasCropOrLivestock && input.activityCount == 0) {
      return FarmLifecycleStage.created;
    }

    // ── Rule 2: Ready for Production (crop/livestock added, no activities) ──
    if (input.hasField && input.hasCropOrLivestock && input.activityCount == 0) {
      return FarmLifecycleStage.readyForProduction;
    }

    // ── Rule 3: Production Started (activities exist, no production records) ──
    if (input.hasField && input.activityCount > 0 && input.productionRecordCount == 0) {
      return FarmLifecycleStage.productionStarted;
    }

    // ── Rule 4: Active Management (multiple activities + production growing) ──
    if (input.hasField && input.activityCount >= 3 && input.productionRecordCount > 0) {
      return FarmLifecycleStage.activeManagement;
    }

    // ── Rule 5: Harvest / Production Complete (production recorded) ──
    if (input.hasField && input.productionRecordCount > 0 && input.activityCount > 0) {
      return FarmLifecycleStage.harvestOrProductionComplete;
    }

    // ── Rule 6: Reporting & Analysis (production + reports) ──
    if (input.hasField && input.productionRecordCount > 0 && input.hasReports) {
      return FarmLifecycleStage.reportingAndAnalysis;
    }

    // ── Fallback ──
    return FarmLifecycleStage.unknown;
  }
}