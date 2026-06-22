import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/module_runtime_sync/application/providers/module_runtime_sync_provider.dart';

/// ============================================================
/// PHASE 6 — TASK D1: RUNTIME DIAGNOSTICS PANEL
/// ============================================================
///
/// Internal developer diagnostics UI.
/// Displays real-time runtime metrics for debugging.
///
/// UI Sections:
/// - Recovery metrics (replay count, durations)
/// - Memory/buffer metrics (buffered events, journal size)
/// - Pipeline metrics (throughput, coalescing)
/// - Health status (healthy/degraded/overflow)
/// - Reconnect state
///
/// This is a DEV-ONLY panel, guarded by [isDevMode] or
/// [RuntimeFeatureFlags.enableDiagnosticsPanel].
/// ============================================================

class RuntimeDiagnosticsPanel extends ConsumerWidget {
  const RuntimeDiagnosticsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostics = ref.watch(runtimeDiagnosticsProvider);
    final health = ref.watch(runtimeHealthProvider);

    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _healthColor(health),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'RUNTIME DIAGNOSTICS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Health Status
            _section('Health Status'),
            _row('Status', health.name),
            _row('Replaying', _b(diagnostics['isReplaying'])),
            _row('Backgrounded', _b(diagnostics['isBackgrounded'])),
            _row('Reconnect Attempts', '${diagnostics['reconnectAttempt']}'),
            const Divider(color: Colors.white24),

            // Recovery Metrics
            _section('Recovery Metrics'),
            _row('Events Replayed', '${diagnostics['replayedEventCount']}'),
            _row('Journal Replay', '${diagnostics['journalReplayDurationMs']}ms'),
            _row('Checkpoint Restore', '${diagnostics['checkpointRestoreDurationMs']}ms'),
            _row('Last Checkpoint Seq', '${diagnostics['lastCheckpointSequence']}'),
            const Divider(color: Colors.white24),

            // Buffer & Memory
            _section('Buffer & Memory'),
            _row('Buffered Events', '${diagnostics['bufferedEventCount']}'),
            _row('Buffer Capacity', '${diagnostics['bufferCapacity']}'),
            _row('Buffer Utilization',
                '${(diagnostics['bufferUtilization'] * 100).toStringAsFixed(1)}%'),
            _row('Near Capacity', _b(diagnostics['bufferNearCapacity'])),
            const Divider(color: Colors.white24),

            // Pipeline Metrics
            _section('Pipeline Metrics'),
            _row('Pipeline Runs', '${diagnostics['pipelineExecutionCount']}'),
            _row('Total Ingested', '${diagnostics['totalEventsIngested']}'),
            _row('Coalesced Batches', '${diagnostics['coalescedBatchCount']}'),
            _row('Adaptive Replay Batches', '${diagnostics['adaptiveReplayBatchesUsed']}'),
            _row('Avg Replay Batch Size', '${diagnostics['avgReplayBatchSize']}'),
            _row('Processing Time', '${diagnostics['totalProcessingTimeMs']}ms'),
            _row('Uptime',
                '${(diagnostics['engineUptimeMs'] / 1000).toStringAsFixed(0)}s'),
            const Divider(color: Colors.white24),

            // Help text
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'For development use only. Enable via RuntimeFeatureFlags.',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Color _healthColor(RuntimeHealthState health) {
    switch (health) {
      case RuntimeHealthState.healthy:
        return Colors.green;
      case RuntimeHealthState.recovering:
        return Colors.orange;
      case RuntimeHealthState.degraded:
        return Colors.orange;
      case RuntimeHealthState.replaying:
        return Colors.blue;
      case RuntimeHealthState.overflow:
        return Colors.red;
      case RuntimeHealthState.corrupted:
        return Colors.deepPurple;
    }
  }

  String _b(dynamic value) {
    if (value == true) return 'YES';
    if (value == false) return 'no';
    return '$value';
  }
}
