class EntityDashboardMemory {
  /// entityId → widget usage map
  final Map<String, Map<String, double>> _entityScores = {};

  void record({
    required String entityId,
    required String widgetKey,
    required double score,
  }) {
    final entityMap = _entityScores[entityId] ?? {};

    entityMap[widgetKey] =
        (entityMap[widgetKey] ?? 0) + score;

    _entityScores[entityId] = entityMap;
  }

  List<String> topWidgets(String entityId) {
    final map = _entityScores[entityId];

    if (map == null) return [];

    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => e.key).toList();
  }
}