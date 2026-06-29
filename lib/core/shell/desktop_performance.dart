/// ============================================================
/// DESKTOP PERFORMANCE MEASUREMENT (PHASE B)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/ = OS-level shell layer
///
/// ✅ Responsibilities:
///   - Measure sidebar rebuilds
///   - Measure dashboard rebuilds
///   - Measure resize latency
///   - Measure animation duration
///   - Track unnecessary rebuilds
///   - Provide performance snapshots
///
/// ❌ Does NOT:
///   - Render UI
///   - Contain business logic
///   - Modify domain state
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ============================================================
/// PERF METRIC
/// ============================================================
class PerfMetric {
  final String name;
  final int valueMs;
  final DateTime timestamp;

  const PerfMetric({
    required this.name,
    required this.valueMs,
    required this.timestamp,
  });
}

/// ============================================================
/// DESKTOP PERFORMANCE METRICS COLLECTOR
/// ============================================================
class DesktopPerformanceMetrics {
  // ── Sidebar rebuilds ──
  int _sidebarRebuildCount = 0;
  int _lastSidebarRebuildMs = 0;
  int _cumulativeSidebarRebuildMs = 0;
  int _maxSidebarRebuildMs = 0;

  // ── Dashboard rebuilds ──
  int _dashboardRebuildCount = 0;
  int _lastDashboardRebuildMs = 0;
  int _cumulativeDashboardRebuildMs = 0;
  int _maxDashboardRebuildMs = 0;

  // ── Resize latency ──
  int _lastResizeLatencyMs = 0;
  int _cumulativeResizeLatencyMs = 0;
  int _maxResizeLatencyMs = 0;
  int _resizeCount = 0;

  // ── Animation duration ──
  int _lastAnimationDurationMs = 0;
  int _cumulativeAnimationDurationMs = 0;
  int _maxAnimationDurationMs = 0;
  int _animationCount = 0;

  // ── Unnecessary rebuilds (rebuilds without state change) ──
  int _unnecessarySidebarRebuilds = 0;
  int _unnecessaryDashboardRebuilds = 0;

  // ── Timing data ──
  final Map<String, List<int>> _timings = {};

  /// ============================================================
  /// RECORD SIDEBAR BUILD
  /// ============================================================
  void recordSidebarBuild(int durationMs) {
    _sidebarRebuildCount++;
    _lastSidebarRebuildMs = durationMs;
    _cumulativeSidebarRebuildMs += durationMs;
    _maxSidebarRebuildMs =
        durationMs > _maxSidebarRebuildMs ? durationMs : _maxSidebarRebuildMs;
    _addTiming('sidebar_rebuild', durationMs);
  }

  /// ============================================================
  /// RECORD DASHBOARD BUILD
  /// ============================================================
  void recordDashboardBuild(int durationMs) {
    _dashboardRebuildCount++;
    _lastDashboardRebuildMs = durationMs;
    _cumulativeDashboardRebuildMs += durationMs;
    _maxDashboardRebuildMs =
        durationMs > _maxDashboardRebuildMs ? durationMs : _maxDashboardRebuildMs;
    _addTiming('dashboard_rebuild', durationMs);
  }

  /// ============================================================
  /// RECORD RESIZE LATENCY
  /// ============================================================
  void recordResizeLatency(int durationMs) {
    _resizeCount++;
    _lastResizeLatencyMs = durationMs;
    _cumulativeResizeLatencyMs += durationMs;
    _maxResizeLatencyMs =
        durationMs > _maxResizeLatencyMs ? durationMs : _maxResizeLatencyMs;
    _addTiming('resize_latency', durationMs);
  }

  /// ============================================================
  /// RECORD ANIMATION DURATION
  /// ============================================================
  void recordAnimationDuration(int durationMs) {
    _animationCount++;
    _lastAnimationDurationMs = durationMs;
    _cumulativeAnimationDurationMs += durationMs;
    _maxAnimationDurationMs =
        durationMs > _maxAnimationDurationMs ? durationMs : _maxAnimationDurationMs;
    _addTiming('animation_duration', durationMs);
  }

  /// ============================================================
  /// RECORD UNNECESSARY SIDEBAR REBUILD
  /// ============================================================
  void recordUnnecessarySidebarRebuild() {
    _unnecessarySidebarRebuilds++;
  }

  /// ============================================================
  /// RECORD UNNECESSARY DASHBOARD REBUILD
  /// ============================================================
  void recordUnnecessaryDashboardRebuild() {
    _unnecessaryDashboardRebuilds++;
  }

  /// ============================================================
  /// ADD TIMING DATA POINT
  /// ============================================================
  void _addTiming(String key, int valueMs) {
    _timings.putIfAbsent(key, () => []);
    _timings[key]!.add(valueMs);
    // Limit to last 1000 data points
    if (_timings[key]!.length > 1000) {
      _timings[key]!.removeAt(0);
    }
  }

  // ── Getters ──

  int get sidebarRebuildCount => _sidebarRebuildCount;
  int get lastSidebarRebuildMs => _lastSidebarRebuildMs;
  double get avgSidebarRebuildMs =>
      _sidebarRebuildCount > 0
          ? _cumulativeSidebarRebuildMs / _sidebarRebuildCount
          : 0;
  int get maxSidebarRebuildMs => _maxSidebarRebuildMs;

  int get dashboardRebuildCount => _dashboardRebuildCount;
  int get lastDashboardRebuildMs => _lastDashboardRebuildMs;
  double get avgDashboardRebuildMs =>
      _dashboardRebuildCount > 0
          ? _cumulativeDashboardRebuildMs / _dashboardRebuildCount
          : 0;
  int get maxDashboardRebuildMs => _maxDashboardRebuildMs;

  int get resizeCount => _resizeCount;
  int get lastResizeLatencyMs => _lastResizeLatencyMs;
  double get avgResizeLatencyMs =>
      _resizeCount > 0 ? _cumulativeResizeLatencyMs / _resizeCount : 0;
  int get maxResizeLatencyMs => _maxResizeLatencyMs;

  int get animationCount => _animationCount;
  int get lastAnimationDurationMs => _lastAnimationDurationMs;
  double get avgAnimationDurationMs =>
      _animationCount > 0
          ? _cumulativeAnimationDurationMs / _animationCount
          : 0;
  int get maxAnimationDurationMs => _maxAnimationDurationMs;

  int get unnecessarySidebarRebuilds => _unnecessarySidebarRebuilds;
  int get unnecessaryDashboardRebuilds => _unnecessaryDashboardRebuilds;

  /// Get timing data for a specific metric
  List<int> getTimings(String key) =>
      List.unmodifiable(_timings[key] ?? []);

  /// ============================================================
  /// SNAPSHOT
  /// ============================================================
  Map<String, dynamic> toJson() => {
        'sidebar': {
          'rebuildCount': _sidebarRebuildCount,
          'lastRebuildMs': _lastSidebarRebuildMs,
          'avgRebuildMs': avgSidebarRebuildMs,
          'maxRebuildMs': _maxSidebarRebuildMs,
          'unnecessaryRebuilds': _unnecessarySidebarRebuilds,
        },
        'dashboard': {
          'rebuildCount': _dashboardRebuildCount,
          'lastRebuildMs': _lastDashboardRebuildMs,
          'avgRebuildMs': avgDashboardRebuildMs,
          'maxRebuildMs': _maxDashboardRebuildMs,
          'unnecessaryRebuilds': _unnecessaryDashboardRebuilds,
        },
        'resize': {
          'count': _resizeCount,
          'lastLatencyMs': _lastResizeLatencyMs,
          'avgLatencyMs': avgResizeLatencyMs,
          'maxLatencyMs': _maxResizeLatencyMs,
        },
        'animation': {
          'count': _animationCount,
          'lastDurationMs': _lastAnimationDurationMs,
          'avgDurationMs': avgAnimationDurationMs,
          'maxDurationMs': _maxAnimationDurationMs,
        },
      };

  /// Reset all metrics
  void reset() {
    _sidebarRebuildCount = 0;
    _lastSidebarRebuildMs = 0;
    _cumulativeSidebarRebuildMs = 0;
    _maxSidebarRebuildMs = 0;
    _dashboardRebuildCount = 0;
    _lastDashboardRebuildMs = 0;
    _cumulativeDashboardRebuildMs = 0;
    _maxDashboardRebuildMs = 0;
    _lastResizeLatencyMs = 0;
    _cumulativeResizeLatencyMs = 0;
    _maxResizeLatencyMs = 0;
    _resizeCount = 0;
    _lastAnimationDurationMs = 0;
    _cumulativeAnimationDurationMs = 0;
    _maxAnimationDurationMs = 0;
    _animationCount = 0;
    _unnecessarySidebarRebuilds = 0;
    _unnecessaryDashboardRebuilds = 0;
    _timings.clear();
  }
}

/// Singleton instance
final desktopPerformance = DesktopPerformanceMetrics();

/// ============================================================
/// PERFORMANCE PERFORMANCE PROVIDER
/// ============================================================
final desktopPerformanceProvider = Provider<DesktopPerformanceMetrics>((ref) {
  return desktopPerformance;
});
