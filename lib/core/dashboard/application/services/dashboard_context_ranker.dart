class DashboardContextRanker {
  /// Final ranking boost before UI render
  double rank({
    required String widgetKey,
    required String moduleKey,
    String? entityId,
    required double baseScore,
  }) {
    double score = baseScore;

    /// module affinity boost
    if (widgetKey.contains(moduleKey)) {
      score += 5;
    }

    /// entity-aware boost placeholder
    if (entityId != null) {
      score += 3;
    }

    return score;
  }
}