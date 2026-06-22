/// ============================================================
/// RUNTIME HEALTH WIDGETS — LIVE OBSERVABILITY UI
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/presentation/widgets/
///
/// ✅ CONSUMES EXISTING PROVIDERS:
///   - operationalDashboardProvider
///   - moduleDegradationProvider
///   - observabilitySummaryProvider
///   - slowModuleListProvider
///   - providerHealthSnapshotProvider
///
/// ✅ RESPONSIBILITIES:
///   - Show module degradation status
///   - Runtime health indicators
///   - Workflow execution monitor
///   - Retry statistics
///   - Telemetry snapshots
///   - Provider health summaries
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/presentation/providers/operational_dashboard_provider.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/observability_providers.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/module_degradation_provider.dart';

/// Module Degradation Status Widget
class ModuleDegradationStatus extends ConsumerWidget {
  const ModuleDegradationStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dashboard = ref.watch(operationalDashboardProvider);
    final degradation = ref.watch(moduleDegradationProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _statusColor(dashboard.overallHealth)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.monitor_heart_rounded,
                  size: 18,
                  color: _statusColor(dashboard.overallHealth),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Runtime Status',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      dashboard.healthLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: _statusColor(dashboard.overallHealth),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'v1.0',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _statRow('Modules', '${dashboard.healthyModules}/${dashboard.totalModules} healthy'),
          const SizedBox(height: 6),
          _statRow('Degraded', '${degradation.degradedCount} module${degradation.degradedCount == 1 ? '' : 's'}'),
          const SizedBox(height: 6),
          _statRow('Uptime', _formatDuration(dashboard.uptime)),
        ],
      ),
    );
  }

  Color _statusColor(status) {
    if (status?.name == 'healthy' || status == 'healthy') return Colors.green;
    if (status?.name == 'degraded' || status == 'degraded') return Colors.orange;
    if (status?.name == 'critical' || status == 'critical') return Colors.red;
    return Colors.grey;
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}

/// Runtime Health Indicators
class RuntimeHealthIndicators extends ConsumerWidget {
  const RuntimeHealthIndicators({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dashboard = ref.watch(operationalDashboardProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.monitor_rounded,
                  size: 18,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'System Metrics',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _statRow('Events (total)', dashboard.totalEvents.toString()),
          const SizedBox(height: 6),
          _statRow('Events/s', dashboard.eventsPerSecond.toStringAsFixed(1)),
          const SizedBox(height: 6),
          _statRow('Failures', dashboard.failures.toString()),
          const SizedBox(height: 6),
          _statRow('Recoveries', dashboard.recoveries.toString()),
          const SizedBox(height: 6),
          _statRow('Recovery Rate',
              '${(dashboard.recoveryRate * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 6),
          _statRow('Avg Patch',
              '${dashboard.averagePatchDurationMs.toStringAsFixed(0)}ms'),
          const SizedBox(height: 6),
          _statRow('P95 Patch',
              '${dashboard.p95PatchDurationMs.toStringAsFixed(0)}ms'),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Workflow Execution Monitor
class WorkflowExecutionMonitor extends ConsumerWidget {
  const WorkflowExecutionMonitor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dashboard = ref.watch(operationalDashboardProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  size: 18,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Workflow Status',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _statRow('Current Streak', dashboard.currentStreak.toString()),
          const SizedBox(height: 6),
          _statRow('Consecutive Failures',
              dashboard.consecutiveFailures.toString()),
          const SizedBox(height: 6),
          _statRow('Slow Modules',
              '${dashboard.slowModuleCount} module${dashboard.slowModuleCount == 1 ? '' : 's'}'),
          if (dashboard.slowestModuleIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 6),
            Text(
              'Slowest:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            ...dashboard.slowestModuleIds.take(3).map((id) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    id.length > 30 ? '${id.substring(0, 30)}...' : id,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade400,
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Retry Statistics
class RetryStatisticsWidget extends ConsumerWidget {
  const RetryStatisticsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resilience = ref.watch(resilienceMetricsProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.replay_rounded,
                  size: 18,
                  color: Colors.cyan,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Resilience',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _statRow('Recovery Rate',
              '${(resilience.recoveryRate * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 6),
          _statRow('Total Failures', resilience.totalFailures.toString()),
          const SizedBox(height: 6),
          _statRow('Total Recoveries',
              resilience.totalRecoveries.toString()),
          const SizedBox(height: 6),
          _statRow('Max Streak', resilience.maxStreak.toString()),
          const SizedBox(height: 6),
          _statRow('Consecutive Failures',
              resilience.consecutiveFailures.toString()),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Provider Health Summary
class ProviderHealthSummary extends ConsumerWidget {
  const ProviderHealthSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final providerHealth = ref.watch(providerHealthSnapshotProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.devices_other_rounded,
                  size: 18,
                  color: Colors.blueGrey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Provider Health',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: providerHealth.allHealthy
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  providerHealth.allHealthy ? 'All OK' : 'Issues',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: providerHealth.allHealthy
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _statRow(
            'Healthy',
            providerHealth.healthyCount.toString(),
          ),
          const SizedBox(height: 6),
          _statRow(
            'Degraded',
            providerHealth.degradedCount.toString(),
          ),
          const SizedBox(height: 6),
          _statRow(
            'Critical',
            providerHealth.criticalCount.toString(),
          ),
          if (providerHealth.unhealthyProviders.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 6),
            Text(
              'Unhealthy:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade600,
              ),
            ),
            ...providerHealth.unhealthyProviders.take(3).map((entry) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    entry.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade400,
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
