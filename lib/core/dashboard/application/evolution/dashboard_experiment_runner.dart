class DashboardExperimentRunner {
  final Map<String, String> activeExperiments = {};

  String assignVariant({
    required String entityId,
    required List<String> layouts,
  }) {
    /// deterministic assignment (stable A/B testing)
    final index = entityId.hashCode % layouts.length;

    final variant = layouts[index];
    activeExperiments[entityId] = variant;

    return variant;
  }
}