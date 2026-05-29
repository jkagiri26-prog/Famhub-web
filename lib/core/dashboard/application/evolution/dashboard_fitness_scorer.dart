class DashboardFitnessScorer {
  double score({
    required int openCount,
    required int interactionCount,
    required double sessionDuration,
    required double conversionRate,
  }) {
    return (openCount * 1.5) +
        (interactionCount * 2.0) +
        (sessionDuration * 1.2) +
        (conversionRate * 10);
  }
}