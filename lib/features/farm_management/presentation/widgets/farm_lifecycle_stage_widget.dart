/// ============================================================
/// FARM LIFECYCLE STAGE WIDGET
/// ============================================================
///
/// 🏗️ Displays the current farm lifecycle stage, health score,
///    and progressive next action.
///
/// This widget replaces the static "Created" success dialog.
/// It adapts dynamically as the farm progresses through stages.
///
/// Integrated with:
///   - FarmLifecycleProvider (stage detection + health)
///   - FarmSeasonProvider (current season display)
///   - HierarchyProvider (current selection)
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/farm_management/domain/enums/farm_lifecycle_stage.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_lifecycle_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_season_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_health_score_service.dart';
import 'package:famhub_app/features/farm_management/domain/services/farm_health_score_service.dart';

/// Displays the current lifecycle progress with stage, health, and next action.
class FarmLifecycleStageWidget extends ConsumerWidget {
  const FarmLifecycleStageWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lifecycle = ref.watch(farmLifecycleProvider);
    final season = ref.watch(farmSeasonProvider);
    final hierarchy = ref.watch(hierarchyProvider);

    if (lifecycle.isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (!hierarchy.hasEntity) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _stageGradient(lifecycle.stage),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stageBorderColor(lifecycle.stage)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Row: Emoji + Stage Name + Season ──
          Row(
            children: [
              Text(
                lifecycle.stage.emoji,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lifecycle.stage.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _stageTextColor(lifecycle.stage),
                      ),
                    ),
                    if (season.currentSeason != null)
                      Text(
                        season.currentSeason!.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: _stageTextColor(lifecycle.stage).withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),


              // ── Health Score Badge (hidden during setup to avoid alarming UX) ──
              if (lifecycle.healthScore != null &&
                  lifecycle.stage != FarmLifecycleStage.created &&
                  lifecycle.stage != FarmLifecycleStage.unknown)
                _buildHealthBadge(context, lifecycle.healthScore!),
            ],
          ),

          // ── Health Score Bars (hidden during setup) ──
          if (lifecycle.healthScore != null &&
              lifecycle.stage != FarmLifecycleStage.created &&
              lifecycle.stage != FarmLifecycleStage.unknown)
            ...[const SizedBox(height: 12), _buildScoreBreakdown(context, lifecycle)],

          // ── Next Progressive Action ──
          if (lifecycle.nextActionLabel != null) ...[const SizedBox(height: 12), _buildNextAction(context, lifecycle, ref)],

          // ── Stage-specific Details ──
          if (lifecycle.stage == FarmLifecycleStage.created) _buildStageTip(context, 'Your Main Field is ready. Add crops or livestock to begin.'),
          if (lifecycle.stage == FarmLifecycleStage.readyForProduction) _buildStageTip(context, 'Crop/Livestock added. Record your first activity to start production tracking.'),
          if (lifecycle.stage == FarmLifecycleStage.reportingAndAnalysis) _buildStageTip(context, 'Season complete! Archive data and prepare for a new season.'),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(BuildContext context, HealthScoreResult health) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _healthColor(health.level).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _healthColor(health.level).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, size: 12, color: _healthColor(health.level)),
          const SizedBox(width: 4),
          Text(
            '${health.score}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _healthColor(health.level),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBreakdown(BuildContext context, FarmLifecycleState lifecycle) {
    final health = lifecycle.healthScore!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Health Score: ${health.score}/100 - ${health.level.label}',
          style: TextStyle(fontSize: 11, color: _stageTextColor(lifecycle.stage).withOpacity(0.6)),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _miniScoreBar('Activity', health.activityScore, 40, Colors.blue),
            const SizedBox(width: 6),
            _miniScoreBar('Production', health.productionScore, 35, Colors.green),
            const SizedBox(width: 6),
            _miniScoreBar('Financial', health.financialScore, 25, Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _miniScoreBar(String label, int score, int maxScore, Color color) {
    final fraction = maxScore > 0 ? (score / maxScore).clamp(0.0, 1.0) : 0.0;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$score', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildNextAction(BuildContext context, FarmLifecycleState lifecycle, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final route = lifecycle.nextActionRoute;
          if (route != null) {
            // Use go_router or Navigator
            Navigator.of(context).pushNamed(route);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.arrow_forward_rounded, size: 16, color: theme.colorScheme.onPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Next: ${lifecycle.nextActionLabel}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 12, color: theme.colorScheme.onPrimary.withOpacity(0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageTip(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.white.withOpacity(0.8)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9), height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Color _stageTextColor(FarmLifecycleStage stage) {
    switch (stage) {
      case FarmLifecycleStage.created:
        return Colors.green.shade900;
      case FarmLifecycleStage.readyForProduction:
        return Colors.teal.shade900;
      case FarmLifecycleStage.productionStarted:
        return Colors.blue.shade900;
      case FarmLifecycleStage.activeManagement:
        return Colors.indigo.shade900;
      case FarmLifecycleStage.harvestOrProductionComplete:
        return Colors.amber.shade900;
      case FarmLifecycleStage.reportingAndAnalysis:
        return Colors.purple.shade900;
      default:
        return Colors.grey.shade900;
    }
  }

  LinearGradient _stageGradient(FarmLifecycleStage stage) {
    switch (stage) {
      case FarmLifecycleStage.created:
        return const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case FarmLifecycleStage.readyForProduction:
        return const LinearGradient(colors: [Color(0xFFE0F2F1), Color(0xFFB2DFDB)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case FarmLifecycleStage.productionStarted:
        return const LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case FarmLifecycleStage.activeManagement:
        return const LinearGradient(colors: [Color(0xFFE8EAF6), Color(0xFFC5CAE9)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case FarmLifecycleStage.harvestOrProductionComplete:
        return const LinearGradient(colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case FarmLifecycleStage.reportingAndAnalysis:
        return const LinearGradient(colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      default:
        return LinearGradient(colors: [Colors.grey.shade100, Colors.grey.shade200], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
  }

  Color _stageBorderColor(FarmLifecycleStage stage) {
    switch (stage) {
      case FarmLifecycleStage.created:
        return Colors.green.shade300;
      case FarmLifecycleStage.readyForProduction:
        return Colors.teal.shade300;
      case FarmLifecycleStage.productionStarted:
        return Colors.blue.shade300;
      case FarmLifecycleStage.activeManagement:
        return Colors.indigo.shade300;
      case FarmLifecycleStage.harvestOrProductionComplete:
        return Colors.amber.shade300;
      case FarmLifecycleStage.reportingAndAnalysis:
        return Colors.purple.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  Color _healthColor(dynamic level) {
    if (level == FarmHealthLevel.excellent) return Colors.green;
    if (level == FarmHealthLevel.good) return Colors.blue;
    if (level == FarmHealthLevel.needsAttention) return Colors.orange;
    if (level == FarmHealthLevel.critical) return Colors.red;
    return Colors.grey;
  }
}