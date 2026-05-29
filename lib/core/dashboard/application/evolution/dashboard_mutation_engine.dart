import 'dashboard_fitness_scorer.dart';

class DashboardMutationEngine {
  final DashboardFitnessScorer scorer;

  DashboardMutationEngine(this.scorer);

  List<String> evolve({
    required List<String> layouts,
    required Map<String, double> usageData,
  }) {
    final scored = <String, double>{};

    for (final layout in layouts) {
      final data = usageData[layout] ?? 0;

      scored[layout] = scorer.score(
        openCount: data.toInt(),
        interactionCount: (data * 1.2).toInt(),
        sessionDuration: data * 0.8,
        conversionRate: data * 0.1,
      );
    }

    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => e.key).toList();
  }
}