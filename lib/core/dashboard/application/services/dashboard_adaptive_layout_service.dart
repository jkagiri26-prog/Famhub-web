import '../../domain/models/dashboard_layout_binding_rule.dart';
import '../../infrastructure/services/dashboard_usage_tracker.dart';

/// ============================================================
/// ADAPTIVE LAYOUT ENGINE (AI-STYLE BEHAVIOR LAYER)
/// ============================================================
///
/// Enhances layout selection using:
/// - backend rules
/// - user behavior
/// - usage frequency
/// - interaction score
/// ============================================================
class DashboardAdaptiveLayoutService {
  final DashboardUsageTracker usageTracker;

  DashboardAdaptiveLayoutService({
    required this.usageTracker,
  });

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

    double scoreRule(DashboardLayoutBindingRule r) {
      double score = r.priority.toDouble();

      // role boost
      if (r.role != null && r.role == role) {
        score += 5;
      }

      // entity boost
      if (r.entityId != null && r.entityId == entityId) {
        score += 10;
      }

      // usage learning boost (AI behavior layer)
      final usageScore =
          usageTracker.score('${moduleKey}_${r.layoutKey}');

      score += usageScore;

      return score;
    }

    candidates.sort((a, b) => scoreRule(b).compareTo(scoreRule(a)));

    return candidates.first.layoutKey;
  }
}