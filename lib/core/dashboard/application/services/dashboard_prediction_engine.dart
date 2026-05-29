import '../tracking/dashboard_usage_tracker.dart';
import '../tracking/entity_dashboard_memory.dart';

class DashboardPredictionEngine {
  final DashboardUsageTracker usageTracker;
  final EntityDashboardMemory entityMemory;

  DashboardPredictionEngine({
    required this.usageTracker,
    required this.entityMemory,
  });

  /// Predict best widgets BEFORE rendering
  List<String> predict({
    required String moduleKey,
    String? entityId,
    List<String> availableWidgets = const [],
  }) {
    final scores = <String, double>{};

    for (final widget in availableWidgets) {
      double score = usageTracker.score(widget);

      /// boost entity relevance
      if (entityId != null) {
        final entityTop =
            entityMemory.topWidgets(entityId);

        if (entityTop.contains(widget)) {
          score += 15; // strong contextual boost
        }
      }

      scores[widget] = score;
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => e.key).toList();
  }
}