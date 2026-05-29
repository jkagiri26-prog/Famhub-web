import 'dashboard_mutation_engine.dart';
import 'dashboard_experiment_runner.dart';

class DashboardEvolutionEngine {
  final DashboardMutationEngine mutationEngine;
  final DashboardExperimentRunner experimentRunner;

  DashboardEvolutionEngine({
    required this.mutationEngine,
    required this.experimentRunner,
  });

  List<String> evolveLayout({
    required String entityId,
    required List<String> layouts,
    required Map<String, double> usageData,
  }) {
    /// STEP 1: mutate based on performance
    final mutated = mutationEngine.evolve(
      layouts: layouts,
      usageData: usageData,
    );

    /// STEP 2: assign experiment variant
    final variant = experimentRunner.assignVariant(
      entityId: entityId,
      layouts: mutated,
    );

    /// STEP 3: ensure variant is first
    mutated.remove(variant);
    return [variant, ...mutated];
  }
}