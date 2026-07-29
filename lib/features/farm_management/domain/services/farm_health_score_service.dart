/// ============================================================
/// FARM HEALTH SCORE SERVICE (Domain Layer)
/// ============================================================
///
/// 🧠 DOMAIN LAYER — PURE DART, NO FLUTTER, NO SUPABASE
///
/// Calculates a dashboard health score for a farm based on:
///   - Activities completed (recency + frequency)
///   - Overdue activities
///   - Production volume
///   - Stock levels
///   - Financial records
///
/// Display levels:
///   - Excellent (≥ 80)
///   - Good (≥ 60)
///   - Needs Attention (≥ 40)
///   - Critical (< 40)
///
/// This is a management indicator, not a financial score.
/// ============================================================
library;

/// Health score display level
enum FarmHealthLevel {
  excellent,
  good,
  needsAttention,
  critical,
  unknown;

  String get label {
    switch (this) {
      case FarmHealthLevel.excellent:
        return 'Excellent';
      case FarmHealthLevel.good:
        return 'Good';
      case FarmHealthLevel.needsAttention:
        return 'Needs Attention';
      case FarmHealthLevel.critical:
        return 'Critical';
      case FarmHealthLevel.unknown:
        return 'N/A';
    }
  }
}

/// Input data for health score calculation
class HealthScoreInput {
  /// Total number of activities ever recorded
  final int totalActivities;

  /// Number of activities recorded in the last 7 days
  final int recentActivities;

  /// Number of overdue/pending tasks
  final int overdueTasks;

  /// Total production quantity (kg)
  final double totalProduction;

  /// Current stock value
  final double stockValue;

  /// Number of financial records
  final int financialRecordCount;

  /// Days since the last activity was recorded (null = never)
  final int? daysSinceLastActivity;

  /// Whether the farm has crops or livestock
  final bool hasCropOrLivestock;

  const HealthScoreInput({
    required this.totalActivities,
    required this.recentActivities,
    required this.overdueTasks,
    required this.totalProduction,
    required this.stockValue,
    required this.financialRecordCount,
    this.daysSinceLastActivity,
    this.hasCropOrLivestock = false,
  });
}

/// Result of health score calculation
class HealthScoreResult {
  /// Numeric score 0-100
  final int score;

  /// Display level
  final FarmHealthLevel level;

  /// Breakdown by category (0-100 each)
  final int activityScore;
  final int productionScore;
  final int financialScore;

  const HealthScoreResult({
    required this.score,
    required this.level,
    required this.activityScore,
    required this.productionScore,
    required this.financialScore,
  });
}

/// Domain service for calculating farm health scores.
class FarmHealthScoreService {
  const FarmHealthScoreService();

  /// Calculate the health score from farm data.
  /// Each category contributes differently based on lifecycle stage.
  HealthScoreResult calculate(HealthScoreInput input) {
    // ── Activity Score (max 40 points) ──
    final activityScore = _calculateActivityScore(input);

    // ── Production Score (max 35 points) ──
    final productionScore = _calculateProductionScore(input);

    // ── Financial Score (max 25 points) ──
    final financialScore = _calculateFinancialScore(input);

    final totalScore = activityScore + productionScore + financialScore;
    final clampedScore = totalScore.clamp(0, 100);

    return HealthScoreResult(
      score: clampedScore,
      level: _determineLevel(clampedScore),
      activityScore: activityScore,
      productionScore: productionScore,
      financialScore: financialScore,
    );
  }

  int _calculateActivityScore(HealthScoreInput input) {
    if (!input.hasCropOrLivestock) return 0;
    if (input.totalActivities == 0) return 5; // Just created, ok

    int score = 0;

    // Regular activity recording (max 15)
    score += (input.totalActivities.clamp(0, 30) / 2).round();

    // Recent activity (max 15)
    if (input.recentActivities >= 5) {
      score += 15;
    } else if (input.recentActivities >= 3) {
      score += 12;
    } else if (input.recentActivities >= 1) {
      score += 8;
    }

    // No overdue tasks (max 10)
    if (input.overdueTasks == 0) {
      score += 10;
    } else if (input.overdueTasks <= 2) {
      score += 5;
    }

    return score.clamp(0, 40);
  }

  int _calculateProductionScore(HealthScoreInput input) {
    if (!input.hasCropOrLivestock) return 0;

    // Production volume (max 25)
    int score = 0;
    if (input.totalProduction > 1000) {
      score += 25;
    } else if (input.totalProduction > 500) {
      score += 20;
    } else if (input.totalProduction > 100) {
      score += 15;
    } else if (input.totalProduction > 0) {
      score += 10;
    }

    // Stock value (max 10)
    if (input.stockValue > 50000) {
      score += 10;
    } else if (input.stockValue > 10000) {
      score += 7;
    } else if (input.stockValue > 0) {
      score += 4;
    }

    return score.clamp(0, 35);
  }

  int _calculateFinancialScore(HealthScoreInput input) {
    if (input.financialRecordCount == 0) return 0;

    int score = 0;

    // Record keeping (max 15)
    if (input.financialRecordCount >= 10) {
      score += 15;
    } else if (input.financialRecordCount >= 5) {
      score += 12;
    } else if (input.financialRecordCount >= 1) {
      score += 8;
    }

    // Recent activity bonus (max 10)
    if (input.daysSinceLastActivity != null && input.daysSinceLastActivity! <= 3) {
      score += 10;
    } else if (input.daysSinceLastActivity != null && input.daysSinceLastActivity! <= 7) {
      score += 5;
    }

    return score.clamp(0, 25);
  }

  FarmHealthLevel _determineLevel(int score) {
    if (score >= 80) return FarmHealthLevel.excellent;
    if (score >= 60) return FarmHealthLevel.good;
    if (score >= 40) return FarmHealthLevel.needsAttention;
    return FarmHealthLevel.critical;
  }
}