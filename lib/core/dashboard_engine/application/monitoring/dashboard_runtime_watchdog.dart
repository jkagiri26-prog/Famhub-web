import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ============================================================
/// DASHBOARD RUNTIME WATCHDOG (v1)
/// ============================================================
///
/// PURPOSE:
/// Lightweight observability component.
///
/// RESPONSIBILITIES:
/// - Track patch execution latency
/// - Track frame scheduler backlog
/// - Maintain rolling metrics history
/// - Expose diagnostics
///
/// NON-RESPONSIBILITIES:
/// - Rollback
/// - Retry control
/// - State recovery
/// - Memory management
/// - Runtime orchestration
///
/// Lifecycle:
/// - Created by Provider
/// - Started/Stopped by RuntimeSyncEngine
/// ============================================================

class HealthMetrics {
  final Duration patchExecutionLatency;
  final int frameSchedulerBacklog;
  final DateTime timestamp;

  const HealthMetrics({
    required this.patchExecutionLatency,
    required this.frameSchedulerBacklog,
    required this.timestamp,
  });

  bool get hasWarning =>
      patchExecutionLatency >= const Duration(milliseconds: 100) ||
      frameSchedulerBacklog >= 10;

  bool get isCritical =>
      patchExecutionLatency >= const Duration(milliseconds: 500) ||
      frameSchedulerBacklog >= 30;
}

enum HealthAlert {
  normal,
  warning,
  critical,
}

class DashboardRuntimeWatchdog {
  DashboardRuntimeWatchdog({
    required this.ref,
  });

  final Ref ref;

  static const int _metricsBufferSize = 60;

  final List<HealthMetrics> _metricsBuffer = [];
  final List<HealthAlert> _alertHistory = [];

  Timer? _timer;

  Duration _lastPatchLatency = Duration.zero;
  int _frameSchedulerBacklog = 0;

  /// ============================================================
  /// LIFECYCLE
  /// ============================================================

  void start() {
    if (_timer != null) return;

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _sample(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// ============================================================
  /// METRIC RECORDING
  /// ============================================================

  void recordPatchLatency(Duration latency) {
    _lastPatchLatency = latency;
  }

  void recordFrameSchedulerBacklog(int backlog) {
    _frameSchedulerBacklog = backlog;
  }

  /// ============================================================
  /// SAMPLING
  /// ============================================================

  void _sample() {
    final metrics = HealthMetrics(
      patchExecutionLatency: _lastPatchLatency,
      frameSchedulerBacklog: _frameSchedulerBacklog,
      timestamp: DateTime.now(),
    );

    _metricsBuffer.add(metrics);

    if (_metricsBuffer.length > _metricsBufferSize) {
      _metricsBuffer.removeAt(0);
    }

    _alertHistory.add(_determineAlert(metrics));

    if (_alertHistory.length > _metricsBufferSize) {
      _alertHistory.removeAt(0);
    }

    /// Reset transient measurements
    _lastPatchLatency = Duration.zero;
  }

  HealthAlert _determineAlert(
    HealthMetrics metrics,
  ) {
    if (metrics.isCritical) {
      return HealthAlert.critical;
    }

    if (metrics.hasWarning) {
      return HealthAlert.warning;
    }

    return HealthAlert.normal;
  }

  /// ============================================================
  /// DIAGNOSTICS
  /// ============================================================

  HealthMetrics? get lastMetrics =>
      _metricsBuffer.isNotEmpty ? _metricsBuffer.last : null;

  List<HealthMetrics> get metricsSnapshot =>
      List.unmodifiable(_metricsBuffer);

  HealthAlert get currentAlert =>
      _alertHistory.isNotEmpty
          ? _alertHistory.last
          : HealthAlert.normal;

  bool get hasWarning =>
      currentAlert == HealthAlert.warning;

  bool get isCritical =>
      currentAlert == HealthAlert.critical;

  double get averagePatchLatencyMs {
    if (_metricsBuffer.isEmpty) {
      return 0;
    }

    final totalMs = _metricsBuffer.fold<int>(
      0,
      (sum, metric) =>
          sum + metric.patchExecutionLatency.inMilliseconds,
    );

    return totalMs / _metricsBuffer.length;
  }

  int get latestFrameBacklog =>
      lastMetrics?.frameSchedulerBacklog ?? 0;

  int get sampleCount => _metricsBuffer.length;
}