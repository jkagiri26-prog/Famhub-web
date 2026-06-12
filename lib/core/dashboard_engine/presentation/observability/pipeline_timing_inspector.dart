import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/observability_providers.dart';

/// ============================================================
/// PIPELINE TIMING INSPECTOR — PHASE 7A
/// ============================================================
///
/// Displays real-time pipeline stage timing with visual bars
/// showing relative duration distribution.
///
/// DEVTOOLS ONLY.
/// ============================================================

class PipelineTimingInspector extends ConsumerStatefulWidget {
  const PipelineTimingInspector({super.key});

  @override
  ConsumerState<PipelineTimingInspector> createState() =>
      _PipelineTimingInspectorState();
}

class _PipelineTimingInspectorState
    extends ConsumerState<PipelineTimingInspector> {
  StreamSubscription<RuntimeTelemetryEvent>? _subscription;
  final List<PipelineTimingRecord> _recentTimings = [];
  static const int _maxRecords = 50;

  @override
  void initState() {
    super.initState();
    _subscribeToEvents();
  }

  void _subscribeToEvents() {
    Future.microtask(() {
      if (!mounted) return;
      final stream = ref.read(rawTelemetryEventStreamProvider.stream);
      _subscription = stream.listen((event) {
        if (!mounted) return;

        if (event.type == TelemetryEventType.pipelineStageCompleted &&
            event.durationMs > 0) {
          setState(() {
            _recentTimings.insert(
              0,
              PipelineTimingRecord(
                stage: event.phase.name,
                durationMs: event.durationMs,
                traceId: event.traceId,
                moduleId: event.moduleId,
                timestamp: event.timestamp,
              ),
            );

            if (_recentTimings.length > _maxRecords) {
              _recentTimings.removeLast();
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_recentTimings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Center(
          child: Text(
            'Waiting for pipeline events...',
            style: TextStyle(
              color: Colors.white38,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ),
      );
    }

    final maxDuration = _recentTimings
        .map((r) => r.durationMs)
        .reduce((a, b) => a > b ? a : b);

    return Container(
      color: const Color(0xFF1A1A2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: const Color(0xFF16213E),
            child: Row(
              children: [
                const Icon(Icons.timeline, color: Colors.cyanAccent, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'PIPELINE TIMING',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Text(
                  '${_recentTimings.length} events',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _recentTimings.clear()),
                  child: const Icon(Icons.clear_all, color: Colors.white38, size: 14),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(4),
              itemCount: _recentTimings.length,
              itemBuilder: (context, index) {
                final record = _recentTimings[index];
                final fraction = maxDuration > 0
                    ? record.durationMs / maxDuration
                    : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          record.stage,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 9,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '${record.durationMs}ms',
                          style: TextStyle(
                            color: _durationColor(record.durationMs),
                            fontSize: 9,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: fraction.clamp(0.01, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: _durationColor(record.durationMs)
                                    .withOpacity(0.6),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (record.moduleId != null)
                        Text(
                          record.moduleId!.length > 12
                              ? '...${record.moduleId!.substring(record.moduleId!.length - 12)}'
                              : record.moduleId!,
                          style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 7,
                            fontFamily: 'monospace',
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _durationColor(int ms) {
    if (ms >= 100) return Colors.redAccent;
    if (ms >= 50) return Colors.orangeAccent;
    if (ms >= 20) return Colors.yellowAccent;
    return Colors.greenAccent;
  }
}

/// Internal record for pipeline timing display
class PipelineTimingRecord {
  final String stage;
  final int durationMs;
  final String traceId;
  final String? moduleId;
  final DateTime timestamp;

  const PipelineTimingRecord({
    required this.stage,
    required this.durationMs,
    required this.traceId,
    this.moduleId,
    required this.timestamp,
  });
}
