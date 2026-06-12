import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/observability_providers.dart';

/// ============================================================
/// REPLAY MONITOR — PHASE 7A
/// ============================================================
///
/// Displays replay-related metrics and health information.
///
/// DEVTOOLS ONLY.
/// ============================================================

class ReplayMonitor extends ConsumerWidget {
  const ReplayMonitor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(latestHealthSnapshotProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.replay, color: Colors.cyanAccent, size: 14),
              SizedBox(width: 6),
              Text(
                'REPLAY MONITOR',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (snapshot == null)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'No replay data yet.',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            )
          else ...[
            _replayRow(
              'Events Replayed',
              '${snapshot.replayedEventCount}',
              icon: Icons.event_note,
            ),
            _replayRow(
              'Journal Replay',
              '${snapshot.journalReplayDurationMs} ms',
              icon: Icons.timer,
              valueColor: snapshot.journalReplayDurationMs > 500
                  ? Colors.orange
                  : null,
            ),
            _replayRow(
              'Checkpoint Restore',
              '${snapshot.checkpointRestoreDurationMs} ms',
              icon: Icons.restore,
            ),
            _replayRow(
              'Events Ingested',
              '${snapshot.totalEventsIngested}',
              icon: Icons.input,
            ),
            _replayRow(
              'Buffer Events',
              '${snapshot.bufferEventCount}',
              icon: Icons.inbox,
            ),
            _replayRow(
              'Health Status',
              snapshot.healthStatus.name.toUpperCase(),
              icon: Icons.monitor_heart,
              valueColor: _healthStatusColor(snapshot.healthStatus),
            ),
            _replayRow(
              'Hydration Latency',
              '${snapshot.hydrationLatencyMs} ms',
              icon: Icons.water_drop,
            ),
          ],
        ],
      ),
    );
  }

  Widget _replayRow(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white38, size: 12),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 140,
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

  Color _healthStatusColor(RuntimeHealthStatus status) {
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
}
