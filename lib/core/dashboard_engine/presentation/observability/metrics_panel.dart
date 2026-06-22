import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/observability/runtime_metrics_collector.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/observability_providers.dart';

/// ============================================================
/// RUNTIME METRICS PANEL — PHASE 7A
/// ============================================================
///
/// Full-page developer diagnostics panel showing all runtime
/// observability metrics.
///
/// DEVTOOLS ONLY — guarded by feature flag.
/// ============================================================

class RuntimeMetricsPanel extends ConsumerWidget {
  const RuntimeMetricsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(observabilitySummaryProvider);
    final snapshot = ref.watch(latestHealthSnapshotProvider);
    final collector = ref.read(runtimeMetricsCollectorProvider);
    final slowModules = ref.watch(slowModuleListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Runtime Observer',
          style: TextStyle(
            color: Colors.cyanAccent,
            fontFamily: 'monospace',
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              ref.read(runtimeMetricsCollectorProvider).reset();
            },
            tooltip: 'Reset metrics',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ═══ HEALTH STATUS ═══
            _card(
              title: 'HEALTH STATUS',
              children: [
                _row('Status', summary.healthStatus.name.toUpperCase(),
                    valueColor: _statusColor(summary.healthStatus)),
                _row('Total Events', '${summary.totalEvents}'),
                _row('Events/sec', summary.eventsPerSecond.toStringAsFixed(1)),
                _row('Failures', '${summary.failures}',
                    valueColor: summary.failures > 0 ? Colors.red : null),
                _row('Dropped Events', '${summary.droppedEvents}',
                    valueColor: summary.droppedEvents > 0 ? Colors.orange : null),
                _row('Buffer Size',
                    '${summary.bufferSize} / ${collector.maxMetricsBufferSize}'),
              ],
            ),
            const SizedBox(height: 12),

            // ═══ PIPELINE TIMING ═══
            _card(
              title: 'PIPELINE TIMING',
              children: [
                _row('Avg Patch Duration',
                    '${summary.averagePatchDurationMs.toStringAsFixed(1)} ms'),
                _row('P50 Patch Duration',
                    '${snapshot?.p50PatchDurationMs.toStringAsFixed(1) ?? "-"} ms'),
                _row('P95 Patch Duration',
                    '${summary.p95PatchDurationMs.toStringAsFixed(1)} ms'),
                _row('P99 Patch Duration',
                    '${snapshot?.p99PatchDurationMs.toStringAsFixed(1) ?? "-"} ms'),
                _row('Total Pipeline Runs', '${snapshot?.totalPipelineRuns ?? 0}'),
                if (snapshot != null) ...[
                  const Divider(color: Colors.white12),
                  _row('Replay Duration',
                      '${snapshot.journalReplayDurationMs} ms'),
                  _row('Checkpoint Restore',
                      '${snapshot.checkpointRestoreDurationMs} ms'),
                  _row('Hydration Latency',
                      '${snapshot.hydrationLatencyMs} ms'),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // ═══ SLOW MODULES ═══
            _card(
              title: 'SLOW MODULES (${slowModules.length})',
              children: [
                if (slowModules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No slow modules detected.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  )
                else
                  ...slowModules.take(10).map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${m.moduleId}${m.widgetKey != null ? "/${m.widgetKey}" : ""}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: _slowColor(m.metricType),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                '${m.metricType}: ${m.actualMs}ms',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '×${m.occurrenceCount}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 9,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
            const SizedBox(height: 12),

            // ═══ QUEUE & BUFFER ═══
            _card(
              title: 'QUEUE & BUFFER',
              children: [
                _row('Coalescer Queue',
                    '${snapshot?.coalescerQueueSize ?? 0}'),
                _row('Frame Scheduler Backlog',
                    '${snapshot?.frameSchedulerBacklog ?? 0}'),
                _row('Reconnect Attempts',
                    '${snapshot?.reconnectAttemptCount ?? 0}'),
                _row('Reconnect Frequency',
                    '${snapshot?.reconnectFrequency ?? 0}'),
                _row('Events Replayed',
                    '${snapshot?.replayedEventCount ?? 0}'),
                _row('Events Ingested',
                    '${snapshot?.totalEventsIngested ?? 0}'),
              ],
            ),

            const SizedBox(height: 12),

            // ═══ COLLECTOR STATS ═══
            _card(
              title: 'COLLECTOR STATS',
              children: [
                _row('Throttled Emissions',
                    '${collector.throttledEmitCount}'),
                _row('Slow Module Count',
                    '${collector.slowModuleCount}'),
                _row('Total Events Tracked',
                    '${collector.totalEvents}'),
                _row('Collector Buffer Size',
                    '${collector.bufferSize}'),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              'DEV-ONLY DIAGNOSTICS PANEL | Phase 7A Observability',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(RuntimeHealthStatus status) {
    switch (status) {
      case RuntimeHealthStatus.healthy:
        return Colors.greenAccent;
      case RuntimeHealthStatus.recovering:
      case RuntimeHealthStatus.degraded:
        return Colors.orangeAccent;
      case RuntimeHealthStatus.replaying:
        return Colors.blueAccent;
      case RuntimeHealthStatus.overflow:
      case RuntimeHealthStatus.corrupted:
        return Colors.redAccent;
    }
  }

  Color _slowColor(String metricType) {
    switch (metricType) {
      case 'patch':
        return Colors.orange;
      case 'replay':
        return Colors.red;
      case 'render':
        return Colors.amber;
      case 'rebuild':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
