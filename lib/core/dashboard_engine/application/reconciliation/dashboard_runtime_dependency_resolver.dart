class DashboardRuntimeDependencyResolver {
  const DashboardRuntimeDependencyResolver();

  /// Example dependency graph
  /// Replace later with registry-driven backend graph
  static const Map<String, List<String>>
  dependencyGraph = {
    'traceability': ['inventory'],
    'marketplace': ['inventory'],
    'analytics': ['marketplace'],
  };

  Set<String> resolveInvalidatedModules(
    Set<String> removedModules,
  ) {
    final invalidated = <String>{};

    for (final entry in dependencyGraph.entries) {
      final module = entry.key;
      final dependencies = entry.value;

      final affected = dependencies.any(
        removedModules.contains,
      );

      if (affected) {
        invalidated.add(module);
      }
    }

    return invalidated;
  }
}