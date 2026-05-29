/// ============================================================
/// WIDGET SCORING SERVICE (APPLICATION INTELLIGENCE LAYER)
/// ============================================================
///
/// Pure scoring engine used to generate usage-based signals.
///
/// Used ONLY for:
/// - DashboardUsageTracker
/// - adaptive ranking signals
///
/// ❌ NOT responsible for:
/// - layout decisions
/// - module control
/// - rendering logic
/// ============================================================
class WidgetScoringService {
  /// Base behavioral score
  int calculateBaseScore({
    required int openCount,
    required int interactionCount,
  }) {
    return (openCount * 2) + (interactionCount * 3);
  }

  /// Recency decay factor (0.2 → 1.0)
  double calculateRecencyWeight(Duration sinceLastAccess) {
    final hours = sinceLastAccess.inHours;

    if (hours < 1) return 1.0;
    if (hours < 24) return 0.9;
    if (hours < 72) return 0.7;
    if (hours < 168) return 0.5;
    return 0.2;
  }

  /// Final normalized score
  double calculateFinalScore({
    required int openCount,
    required int interactionCount,
    required Duration sinceLastAccess,
  }) {
    final base = calculateBaseScore(
      openCount: openCount,
      interactionCount: interactionCount,
    );

    final weight = calculateRecencyWeight(sinceLastAccess);

    return base * weight;
  }
}