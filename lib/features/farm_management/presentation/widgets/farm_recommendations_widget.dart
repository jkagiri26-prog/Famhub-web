/// ============================================================
/// FARM RECOMMENDATIONS WIDGET
/// ============================================================
///
/// 🏗️ Displays contextual recommendations based on lifecycle stage
///    and farm data.
///
/// Integrated with:
///   - FarmRecommendationEngine
///   - FarmLifecycleProvider
///   - WidgetRegistry
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_lifecycle_provider.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_recommendation_engine.dart';

/// Dashboard widget that shows contextual recommendations.
class FarmRecommendationsWidget extends ConsumerWidget {
  const FarmRecommendationsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifecycle = ref.watch(farmLifecycleProvider);
    final theme = Theme.of(context);

    if (lifecycle.recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show top 3 recommendations by priority
    final topRecommendations = lifecycle.recommendations.take(3).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 20, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(
                'Recommendations',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (lifecycle.recommendations.length > 3)
                Text(
                  '+${lifecycle.recommendations.length - 3} more',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Recommendation Items ──
          ...topRecommendations.map((r) => _buildRecommendationItem(context, r, theme)),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem(
    BuildContext context,
    FarmRecommendation recommendation,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _severityBackground(recommendation.severity).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _severityBackground(recommendation.severity).withOpacity(0.2)),
        ),
        child: InkWell(
          onTap: recommendation.actionRoute != null
              ? () => Navigator.of(context).pushNamed(recommendation.actionRoute!)
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Severity indicator
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _severityBackground(recommendation.severity),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      recommendation.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (recommendation.actionLabel != null) ...[const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    recommendation.actionLabel!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _severityBackground(RecommendationSeverity severity) {
    switch (severity) {
      case RecommendationSeverity.critical:
        return Colors.red;
      case RecommendationSeverity.high:
        return Colors.orange;
      case RecommendationSeverity.medium:
        return Colors.blue;
      case RecommendationSeverity.low:
        return Colors.grey;
      case RecommendationSeverity.info:
        return Colors.teal;
    }
  }
}