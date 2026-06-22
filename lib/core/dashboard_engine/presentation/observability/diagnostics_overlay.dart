import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/providers/observability_providers.dart';

/// ============================================================
/// RUNTIME DIAGNOSTICS OVERLAY — PHASE 7A
/// ============================================================
///
/// PURPOSE:
/// Developer-focused diagnostics overlay for the dashboard engine.
/// Provides real-time visibility into runtime health, pipeline
/// performance, and slow module detection.
///
/// IMPORTANT:
/// This is DEVTOOLS ONLY — not for production use.
/// Controlled by [diagnosticsPanelVisibleProvider].
/// ============================================================

class DiagnosticsOverlay extends ConsumerStatefulWidget {
  const DiagnosticsOverlay({super.key});

  @override
  ConsumerState<DiagnosticsOverlay> createState() => _DiagnosticsOverlayState();
}

class _DiagnosticsOverlayState extends ConsumerState<DiagnosticsOverlay> {
  StreamSubscription<RuntimeHealthSnapshot>? _snapshotSubscription;
  RuntimeHealthSnapshot? _latestSnapshot;
  int _snapshotCount = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToSnapshots();
  }

  void _subscribeToSnapshots() {
    // Use ref.listen to subscribe to the stream provider
    ref.listen<AsyncValue<RuntimeHealthSnapshot>>(
      runtimeHealthSnapshotStreamProvider,
      (previous, next) {
        next.whenData((snapshot) {
          if (mounted) {
            setState(() {
              _latestSnapshot = snapshot;
              _snapshotCount++;
            });
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _snapshotSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(diagnosticsPanelVisibleProvider);

    if (!visible) return const SizedBox.shrink();

    final summary = ref.watch(observabilitySummaryProvider);

    return Material(
      color: Colors.black87,
      child: SafeArea(
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            // Swipe up to close
            if (details.primaryVelocity != null &&
                details.primaryVelocity! < -500) {
              ref.read(diagnosticsPanelVisibleProvider.notifier).hide();
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Status Bar ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _healthColor(summary.healthStatus),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monitor_heart, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'RUNTIME OBSERVABILITY',
                      style: _labelStyle(Colors.white, bold: true),
                    ),
                    const Spacer(),
                    Text(
                      summary.healthStatus.name.toUpperCase(),
                      style: _labelStyle(Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${summary.eventsPerSecond.toStringAsFixed(1)} eps',
                      style: _labelStyle(Colors.white70, size: 10),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () =>
                          ref.read(diagnosticsPanelVisibleProvider.notifier).hide(),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ],
                ),
              ),

              // ── Metrics Content ──
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection('PIPELINE PERFORMANCE', [
                        _metricRow('Avg Patch',
                            '${summary.averagePatchDurationMs.toStringAsFixed(1)} ms'),
                        _metricRow('P95 Patch',
                            '${summary.p95PatchDurationMs.toStringAsFixed(1)} ms'),
                        _metricRow('Total Events',
                            '${summary.totalEvents}'),
                        _metricRow('EPS',
                            summary.eventsPerSecond.toStringAsFixed(1)),
                      ]),

                      const SizedBox(height: 6),
                      _buildSection('HEALTH', [
                        _metricRow('Status',
                            summary.healthStatus.name.toUpperCase()),
                        _metricRow('Failures',
                            '${summary.failures}'),
                        _metricRow('Dropped',
                            '${summary.droppedEvents}'),
                        _metricRow('Buffer',
                            '${summary.bufferSize}'),
                      ]),

                      if (summary.slowModuleCount > 0) ...[
                        const SizedBox(height: 6),
                        _buildSection(
                            'SLOW MODULES (${summary.slowModuleCount})', [
                          if (_latestSnapshot != null)
                            ...(_latestSnapshot!.slowestModules.take(5).map(
                                  (m) => _metricRow(
                                    '${m.moduleId}${m.widgetKey != null ? '/${m.widgetKey}' : ''}',
                                    '${m.actualMs}ms (${m.metricType})',
                                    valueColor: Colors.orangeAccent,
                                  ),
                                )),
                        ]),
                      ],

                      const SizedBox(height: 6),
                      _buildSection('SNAPSHOTS', [
                        _metricRow('Updates', '$_snapshotCount'),
                        if (_latestSnapshot != null)
                          _metricRow(
                            'Last',
                            _timeAgo(_latestSnapshot!.snapshotAt),
                          ),
                      ]),

                      // ── Help text ──
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'DEV-ONLY | Swipe up to close',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontWeight: FontWeight.w600,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        ...children,
      ],
    );
  }

  Widget _metricRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle(Color color, {bool bold = false, double size = 11}) {
    return TextStyle(
      color: color,
      fontSize: size,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontFamily: 'monospace',
    );
  }

  Color _healthColor(RuntimeHealthStatus status) {
    switch (status) {
      case RuntimeHealthStatus.healthy:
        return Colors.green;
      case RuntimeHealthStatus.recovering:
      case RuntimeHealthStatus.degraded:
        return Colors.orange;
      case RuntimeHealthStatus.replaying:
        return Colors.blue;
      case RuntimeHealthStatus.overflow:
      case RuntimeHealthStatus.corrupted:
        return Colors.red;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 5) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    return '${diff.inMinutes}m ago';
  }
}
