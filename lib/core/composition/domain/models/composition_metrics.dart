import 'package:flutter/foundation.dart';

/// ============================================================
/// COMPOSITION METRICS (OBSERVABILITY)
/// ============================================================
///
/// Tracks timing and outcome data for runtime composition operations.
/// Used by the observability layer for monitoring and debugging.
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/domain/models/ = composition domain
///
/// ✅ Responsibilities:
///   - Immutable snapshot of composition run metrics
///   - Tracks modules loaded, hidden, denied
///   - Tracks timing for each composition phase
///
/// ❌ Does NOT:
///   - Collect metrics itself (metrics are recorded externally)
///   - Reference any services or providers
/// ============================================================
@immutable
class CompositionMetrics {
  // ── Module Counts ──
  final int modulesLoaded;
  final int modulesHidden;
  final int modulesDenied;
  final int dependencyFailures;
  final int widgetFailures;
  final int moduleLoadFailures;

  // ── Denial Reasons ──
  final Map<String, int> denialReasonCounts;

  // ── Timing (ms) ──
  final int compositionDurationMs;
  final int navigationBuildDurationMs;
  final int dashboardBuildDurationMs;
  final int routeRegistrationDurationMs;

  // ── Registry ──
  final int registryCacheHits;
  final int registryCacheMisses;

  // ── Timestamp ──
  final DateTime recordedAt;

  const CompositionMetrics({
    this.modulesLoaded = 0,
    this.modulesHidden = 0,
    this.modulesDenied = 0,
    this.dependencyFailures = 0,
    this.widgetFailures = 0,
    this.moduleLoadFailures = 0,
    this.denialReasonCounts = const {},
    this.compositionDurationMs = 0,
    this.navigationBuildDurationMs = 0,
    this.dashboardBuildDurationMs = 0,
    this.routeRegistrationDurationMs = 0,
    this.registryCacheHits = 0,
    this.registryCacheMisses = 0,
    required this.recordedAt,
  });

  /// Total modules processed
  int get totalProcessed =>
      modulesLoaded + modulesHidden + modulesDenied;

  /// Registry cache hit rate (0.0 - 1.0)
  double get registryCacheHitRate {
    final total = registryCacheHits + registryCacheMisses;
    return total > 0 ? registryCacheHits / total : 0;
  }

  /// Average composition time per module
  double get avgCompositionTimePerModule {
    if (modulesLoaded == 0) return 0;
    return compositionDurationMs / modulesLoaded;
  }

  Map<String, dynamic> toJson() => {
        'modulesLoaded': modulesLoaded,
        'modulesHidden': modulesHidden,
        'modulesDenied': modulesDenied,
        'dependencyFailures': dependencyFailures,
        'widgetFailures': widgetFailures,
        'moduleLoadFailures': moduleLoadFailures,
        'denialReasonCounts': denialReasonCounts,
        'compositionDurationMs': compositionDurationMs,
        'navigationBuildDurationMs': navigationBuildDurationMs,
        'dashboardBuildDurationMs': dashboardBuildDurationMs,
        'routeRegistrationDurationMs': routeRegistrationDurationMs,
        'registryCacheHitRate': registryCacheHitRate,
        'totalProcessed': totalProcessed,
        'recordedAt': recordedAt.toIso8601String(),
      };

  @override
  String toString() =>
      'CompositionMetrics(loaded=$modulesLoaded, '
      'hidden=$modulesHidden, denied=$modulesDenied, '
      'composition=${compositionDurationMs}ms)';
}

/// ============================================================
/// COMPOSITION METRICS COLLECTOR (SINGLETON)
/// ============================================================
///
/// Collects runtime composition metrics throughout the app lifecycle.
/// Reset periodically or on full recomposition.
/// ============================================================
class CompositionMetricsCollector {
  // ── Module Counts ──
  int _modulesLoaded = 0;
  int _modulesHidden = 0;
  int _modulesDenied = 0;
  int _dependencyFailures = 0;
  int _widgetFailures = 0;
  int _moduleLoadFailures = 0;

  // ── Denial Reasons ──
  final Map<String, int> _denialReasonCounts = {};

  // ── Timing ──
  int _compositionDurationMs = 0;
  int _navigationBuildDurationMs = 0;
  int _dashboardBuildDurationMs = 0;
  int _routeRegistrationDurationMs = 0;

  // ── Registry ──
  int _registryCacheHits = 0;
  int _registryCacheMisses = 0;

  // ── Record Methods ──

  void recordModuleLoaded() => _modulesLoaded++;
  void recordModuleHidden() => _modulesHidden++;
  void recordModuleDenied(String reason) {
    _modulesDenied++;
    _denialReasonCounts[reason] =
        (_denialReasonCounts[reason] ?? 0) + 1;
  }

  void recordDependencyFailure() => _dependencyFailures++;
  void recordWidgetFailure() => _widgetFailures++;
  void recordModuleLoadFailure() => _moduleLoadFailures++;

  void recordCompositionDuration(int ms) => _compositionDurationMs = ms;
  void recordNavigationBuildDuration(int ms) =>
      _navigationBuildDurationMs = ms;
  void recordDashboardBuildDuration(int ms) =>
      _dashboardBuildDurationMs = ms;
  void recordRouteRegistrationDuration(int ms) =>
      _routeRegistrationDurationMs = ms;

  void recordRegistryCacheHit() => _registryCacheHits++;
  void recordRegistryCacheMiss() => _registryCacheMisses++;

  /// Take a snapshot and reset counters
  CompositionMetrics takeSnapshot() {
    final metrics = CompositionMetrics(
      modulesLoaded: _modulesLoaded,
      modulesHidden: _modulesHidden,
      modulesDenied: _modulesDenied,
      dependencyFailures: _dependencyFailures,
      widgetFailures: _widgetFailures,
      moduleLoadFailures: _moduleLoadFailures,
      denialReasonCounts: Map.from(_denialReasonCounts),
      compositionDurationMs: _compositionDurationMs,
      navigationBuildDurationMs: _navigationBuildDurationMs,
      dashboardBuildDurationMs: _dashboardBuildDurationMs,
      routeRegistrationDurationMs: _routeRegistrationDurationMs,
      registryCacheHits: _registryCacheHits,
      registryCacheMisses: _registryCacheMisses,
      recordedAt: DateTime.now(),
    );
    reset();
    return metrics;
  }

  /// Reset all counters (called after snapshot)
  void reset() {
    _modulesLoaded = 0;
    _modulesHidden = 0;
    _modulesDenied = 0;
    _dependencyFailures = 0;
    _widgetFailures = 0;
    _moduleLoadFailures = 0;
    _denialReasonCounts.clear();
    _compositionDurationMs = 0;
    _navigationBuildDurationMs = 0;
    _dashboardBuildDurationMs = 0;
    _routeRegistrationDurationMs = 0;
    _registryCacheHits = 0;
    _registryCacheMisses = 0;
  }
}

/// Singleton instance for app-wide metrics collection
final compositionMetricsCollector = CompositionMetricsCollector();
