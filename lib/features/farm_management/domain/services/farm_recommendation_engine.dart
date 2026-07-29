/// ============================================================
/// FARM RECOMMENDATION ENGINE (Domain Layer)
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Generates contextual, actionable recommendations based on:
///   - Farm lifecycle stage
///   - Recent activities
///   - Overdue actions
///   - Missing data
///
/// Each recommendation is contextual (not generic) and includes
/// an action the user can take immediately.
/// ============================================================
library;

import 'package:famhub_app/features/farm_management/domain/enums/farm_lifecycle_stage.dart';

/// A single contextual recommendation
class FarmRecommendation {
  /// Unique identifier for this recommendation
  final String id;

  /// Display title (short, actionable)
  final String title;

  /// Detailed description explaining why this matters
  final String description;

  /// Severity/priority level
  final RecommendationSeverity severity;

  /// Category of the recommendation
  final RecommendationCategory category;

  /// Optional action route/identifier
  final String? actionRoute;

  /// Optional action label for the button
  final String? actionLabel;

  /// Whether this recommendation should auto-dismiss
  final bool autoDismiss;

  const FarmRecommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.category,
    this.actionRoute,
    this.actionLabel,
    this.autoDismiss = true,
  });
}

/// Priority/severity level
enum RecommendationSeverity {
  critical,
  high,
  medium,
  low,
  info;

  int get priorityValue {
    switch (this) {
      case RecommendationSeverity.critical:
        return 0;
      case RecommendationSeverity.high:
        return 1;
      case RecommendationSeverity.medium:
        return 2;
      case RecommendationSeverity.low:
        return 3;
      case RecommendationSeverity.info:
        return 4;
    }
  }
}

/// Category grouping
enum RecommendationCategory {
  crop,
  livestock,
  activity,
  harvest,
  financial,
  stock,
  report,
  setup,
}

/// Input data for recommendation generation
class RecommendationInput {
  final FarmLifecycleStage stage;
  final bool hasCrop;
  final bool hasLivestock;
  final bool hasField;
  final int activityCount;
  final int daysSinceLastActivity;
  final bool hasPendingHarvest;
  final bool hasProductionRecords;
  final bool hasReports;
  final int overdueTaskCount;
  final bool hasStockBelowThreshold;
  final int? daysSinceLastFinancialRecord;

  const RecommendationInput({
    required this.stage,
    required this.hasCrop,
    required this.hasLivestock,
    required this.hasField,
    required this.activityCount,
    required this.daysSinceLastActivity,
    required this.hasPendingHarvest,
    required this.hasProductionRecords,
    required this.hasReports,
    required this.overdueTaskCount,
    required this.hasStockBelowThreshold,
    this.daysSinceLastFinancialRecord,
  });
}

/// Generates contextual recommendations based on farm data.
class FarmRecommendationEngine {
  const FarmRecommendationEngine();

  /// Generate recommendations for the given farm context.
  /// Returns sorted list (highest priority first).
  List<FarmRecommendation> generate(RecommendationInput input) {
    final recommendations = <FarmRecommendation>[];

    // ── Stage-specific recommendations ──
    recommendations.addAll(_stageRecommendations(input));

    // ── Cross-cutting recommendations ──
    if (input.daysSinceLastActivity > 7 && input.activityCount > 0) {
      recommendations.add(FarmRecommendation(
        id: 'inactivity_7_days',
        title: 'No recent activities recorded',
        description: 'It has been ${input.daysSinceLastActivity} days since your last activity. '
            'Regular recording helps track farm progress.',
        severity: RecommendationSeverity.medium,
        category: RecommendationCategory.activity,
        actionRoute: '/farm/activities/create',
        actionLabel: 'Record Activity',
      ));
    }

    if (input.overdueTaskCount > 0) {
      recommendations.add(FarmRecommendation(
        id: 'overdue_tasks',
        title: '${input.overdueTaskCount} task${input.overdueTaskCount > 1 ? 's' : ''} overdue',
        description: 'You have pending tasks that require attention.',
        severity: RecommendationSeverity.high,
        category: RecommendationCategory.activity,
        actionRoute: '/farm/activities',
        actionLabel: 'View Tasks',
      ));
    }

    if (input.hasStockBelowThreshold) {
      recommendations.add(FarmRecommendation(
        id: 'low_stock',
        title: 'Stock levels are low',
        description: 'Some inputs or supplies are running low. Consider restocking.',
        severity: RecommendationSeverity.medium,
        category: RecommendationCategory.stock,
        actionRoute: '/farm/assets',
        actionLabel: 'View Stock',
      ));
    }

    if (input.daysSinceLastFinancialRecord != null &&
        input.daysSinceLastFinancialRecord! > 30) {
      recommendations.add(FarmRecommendation(
        id: 'financial_overdue',
        title: 'Financial records not updated recently',
        description: 'It has been ${input.daysSinceLastFinancialRecord} days since your last financial record.',
        severity: RecommendationSeverity.medium,
        category: RecommendationCategory.financial,
        actionRoute: '/farm/reports',
        actionLabel: 'Update Records',
      ));
    }

    recommendations.sort((a, b) => a.severity.priorityValue.compareTo(b.severity.priorityValue));
    return recommendations;
  }

  List<FarmRecommendation> _stageRecommendations(RecommendationInput input) {
    switch (input.stage) {
      case FarmLifecycleStage.created:
        return [
          FarmRecommendation(
            id: 'add_first_crop',
            title: 'Add your first crop',
            description: 'Begin managing your Main Field by planting a crop. '
                'This is the first step to tracking your farm\'s production.',
            severity: RecommendationSeverity.critical,
            category: RecommendationCategory.crop,
            actionRoute: '/farm/crops/create',
            actionLabel: 'Add Crop',
          ),
          if (!input.hasLivestock)
            FarmRecommendation(
              id: 'add_first_livestock',
              title: 'Add livestock to your farm',
              description: 'If you manage animals, add them now to start tracking health and production.',
              severity: RecommendationSeverity.medium,
              category: RecommendationCategory.livestock,
              actionRoute: '/farm/livestock/create',
              actionLabel: 'Add Livestock',
            ),
        ];

      case FarmLifecycleStage.readyForProduction:
        return [
          FarmRecommendation(
            id: 'record_first_activity',
            title: 'Record your first activity',
            description: 'Your crop or livestock is set up. Start tracking by recording your first farming activity.',
            severity: RecommendationSeverity.high,
            category: RecommendationCategory.activity,
            actionRoute: '/farm/activities/create',
            actionLabel: 'Record Activity',
          ),
        ];

      case FarmLifecycleStage.productionStarted:
        return [
          FarmRecommendation(
            id: 'track_production',
            title: 'Start tracking production',
            description: 'You\'ve recorded activities. Now begin tracking harvest or production output.',
            severity: RecommendationSeverity.high,
            category: RecommendationCategory.harvest,
            actionRoute: '/farm/production/record',
            actionLabel: 'Record Production',
          ),
        ];

      case FarmLifecycleStage.activeManagement:
        return [
          if (input.hasPendingHarvest)
            FarmRecommendation(
              id: 'harvest_due',
              title: 'Harvest may be due',
              description: 'Your crops may be ready for harvest based on their growing period.',
              severity: RecommendationSeverity.high,
              category: RecommendationCategory.harvest,
              actionRoute: '/farm/harvest',
              actionLabel: 'Check Crops',
            ),
          FarmRecommendation(
            id: 'view_production',
            title: 'Review your production',
            description: 'Check your production dashboard for yield trends and insights.',
            severity: RecommendationSeverity.low,
            category: RecommendationCategory.report,
            actionRoute: '/farm/production',
            actionLabel: 'View Production',
          ),
        ];

      case FarmLifecycleStage.harvestOrProductionComplete:
        return [
          if (input.hasReports)
            FarmRecommendation(
              id: 'view_reports',
              title: 'Your production report is ready',
              description: 'View your farm\'s performance summary including yield, expenses, and sales.',
              severity: RecommendationSeverity.medium,
              category: RecommendationCategory.report,
              actionRoute: '/farm/reports',
              actionLabel: 'View Reports',
            )
          else
            FarmRecommendation(
              id: 'generate_report',
              title: 'Generate a production report',
              description: 'Summarize your production data to analyze farm performance.',
              severity: RecommendationSeverity.medium,
              category: RecommendationCategory.report,
              actionRoute: '/farm/reports/generate',
              actionLabel: 'Generate Report',
            ),
        ];

      case FarmLifecycleStage.reportingAndAnalysis:
        return [
          FarmRecommendation(
            id: 'start_new_season',
            title: 'Start a new season',
            description: 'The current season is complete. Archive data and begin a fresh production cycle.',
            severity: RecommendationSeverity.info,
            category: RecommendationCategory.setup,
            actionRoute: '/farm/seasons/new',
            actionLabel: 'New Season',
          ),
          FarmRecommendation(
            id: 'compare_reports',
            title: 'Compare with previous seasons',
            description: 'View historical reports to identify trends and improve next season.',
            severity: RecommendationSeverity.low,
            category: RecommendationCategory.report,
            actionRoute: '/farm/reports/history',
            actionLabel: 'View History',
          ),
        ];

      case FarmLifecycleStage.unknown:
        return [
          FarmRecommendation(
            id: 'complete_setup',
            title: 'Complete farm setup',
            description: 'Add fields and start managing your farm to unlock production tracking.',
            severity: RecommendationSeverity.critical,
            category: RecommendationCategory.setup,
            actionRoute: '/farm/setup',
            actionLabel: 'Complete Setup',
          ),
        ];
    }
  }
}