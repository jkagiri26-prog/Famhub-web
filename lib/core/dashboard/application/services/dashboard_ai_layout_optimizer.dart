import '../../domain/models/dashboard_layout_binding_rule.dart';
import '../tracking/dashboard_usage_tracker.dart';

/// ============================================================
/// AI LAYOUT OPTIMIZER (CORE DASHBOARD INTELLIGENCE LAYER)
/// ============================================================
///
/// Enhances layout selection using:
/// - backend rules
/// - usage behavior
/// - contextual scoring
/// - adaptive ranking
/// ============================================================
class DashboardAiLayoutOptimizer {
  final DashboardUsageTracker usageTracker;

  DashboardAiLayoutOptimizer({
    required this.usageTracker,
  });

  /// Returns BEST layoutKey based on AI scoring
  String resolveBestLayout({
    required List<DashboardLayoutBindingRule> rules,
    required String moduleKey,
    required String deviceType,
    String? role,
    String? entityId,
  }) {
    final candidates = rules.where((r) {
      return r.moduleKey == moduleKey &&
          r.device == deviceType &&
          r.isActive;
    }).toList();

    if (candidates.isEmpty) return '';

    double score(DashboardLayoutBindingRule r) {
      double s = r.priority.toDouble();

      /// ROLE BOOST
      if (role != null && r.role == role) {
        s += 5;
      }

      /// ENTITY BOOST (highest contextual priority)
      if (entityId != null && r.entityId == entityId) {
        s += 10;
      }

      /// DEVICE MATCH STABILITY BOOST
      if (r.device == deviceType) {
        s += 2;
      }

      /// USAGE LEARNING BOOST (AI SIGNAL)
      final usageKey = '${moduleKey}_${r.layoutKey}';
      s += usageTracker.score(usageKey);

      return s;
    }

    candidates.sort((a, b) => score(b).compareTo(score(a)));

    return candidates.first.layoutKey;
  }
}