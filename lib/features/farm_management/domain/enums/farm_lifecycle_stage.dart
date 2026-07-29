/// ============================================================
/// FARM LIFECYCLE STAGE ENUM
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Represents the calculated lifecycle stage of a farm.
/// Stages are NEVER manually set by the user — they are
/// automatically derived from existing data:
///
///   Farm → Field → Crop/Livestock → Activity → Production → Report
///
/// This enum drives the entire lifecycle-aware UI:
///   - Dashboard widget priority
///   - Quick action suggestions
///   - Smart recommendations
///   - Health score weighting
///   - AI context exposure
/// ============================================================
library;

/// Lifecycle stages of a farm, automatically determined.
enum FarmLifecycleStage {
  /// Farm & Main Field exist. No crops or livestock yet.
  /// The user just created the farm.
  created,

  /// Crop or livestock has been added. First activity not yet recorded.
  readyForProduction,

  /// At least one activity has been recorded.
  /// No production/harvest records yet.
  productionStarted,

  /// Multiple activities recorded and production is growing.
  /// This is the ongoing management phase.
  activeManagement,

  /// Harvest or production records exist.
  /// The crop/livestock lifecycle is closing.
  harvestOrProductionComplete,

  /// Production complete, reports available for analysis.
  /// End of the season cycle.
  reportingAndAnalysis,

  /// Fallback when insufficient data to determine stage.
  unknown;

  /// Human-readable stage label
  String get label {
    switch (this) {
      case FarmLifecycleStage.created:
        return 'Created';
      case FarmLifecycleStage.readyForProduction:
        return 'Ready for Production';
      case FarmLifecycleStage.productionStarted:
        return 'Production Started';
      case FarmLifecycleStage.activeManagement:
        return 'Active Management';
      case FarmLifecycleStage.harvestOrProductionComplete:
        return 'Harvest / Production Complete';
      case FarmLifecycleStage.reportingAndAnalysis:
        return 'Reporting & Analysis';
      case FarmLifecycleStage.unknown:
        return 'Unknown';
    }
  }

  /// Emoji representation for dashboard
  String get emoji {
    switch (this) {
      case FarmLifecycleStage.created:
        return '🌱';
      case FarmLifecycleStage.readyForProduction:
        return '🌿';
      case FarmLifecycleStage.productionStarted:
        return '🚜';
      case FarmLifecycleStage.activeManagement:
        return '🌾';
      case FarmLifecycleStage.harvestOrProductionComplete:
        return '🏆';
      case FarmLifecycleStage.reportingAndAnalysis:
        return '📊';
      case FarmLifecycleStage.unknown:
        return '❓';
    }
  }

  /// Priority order (lower = higher priority for dashboard display)
  int get priority {
    switch (this) {
      case FarmLifecycleStage.created:
        return 1;
      case FarmLifecycleStage.readyForProduction:
        return 2;
      case FarmLifecycleStage.productionStarted:
        return 3;
      case FarmLifecycleStage.activeManagement:
        return 4;
      case FarmLifecycleStage.harvestOrProductionComplete:
        return 5;
      case FarmLifecycleStage.reportingAndAnalysis:
        return 6;
      case FarmLifecycleStage.unknown:
        return 99;
    }
  }

  /// Whether this stage needs immediate user action
  bool get requiresAction => this == FarmLifecycleStage.created ||
      this == FarmLifecycleStage.readyForProduction;

  /// Whether the farm is actively producing
  bool get isActive => this == FarmLifecycleStage.productionStarted ||
      this == FarmLifecycleStage.activeManagement;

  /// Whether data should be archived for a new season
  bool get isTerminal => this == FarmLifecycleStage.reportingAndAnalysis;
}