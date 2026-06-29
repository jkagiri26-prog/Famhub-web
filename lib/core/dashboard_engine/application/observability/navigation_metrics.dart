import 'dart:math';

/// ============================================================
/// NAVIGATION & DASHBOARD OBSERVABILITY METRICS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/observability/ = observability
///
/// ✅ Responsibilities:
///   - Track navigation build times
///   - Track dashboard render times
///   - Track widget failures
///   - Track module load times
///   - Track registry cache hits
///   - Track context resolution
///   - Track runtime synchronization latency
///
/// ❌ Does NOT:
///   - Render UI
///   - Control execution flow
///   - Mutate domain state
/// ============================================================

/// ============================================================
/// NAVIGATION METRICS COLLECTOR
/// ============================================================
///
/// Collects timing and performance data for navigation operations.
/// Used by the observability layer to expose metrics.
/// ============================================================
class NavigationMetrics {
  /// Navigation build timing (ms)
  int _lastSidebarBuildMs = 0;
  int _lastBottomNavBuildMs = 0;
  int _totalSidebarBuilds = 0;
  int _totalBottomNavBuilds = 0;
  int _cumulativeSidebarBuildMs = 0;
  int _cumulativeBottomNavBuildMs = 0;
  int _maxSidebarBuildMs = 0;
  int _maxBottomNavBuildMs = 0;

  /// Dashboard render timing (ms)
  int _lastDashboardRenderMs = 0;
  int _totalDashboardRenders = 0;
  int _cumulativeDashboardRenderMs = 0;
  int _maxDashboardRenderMs = 0;

  /// Widget failure count
  int _widgetFailureCount = 0;
  final Map<String, int> _widgetFailuresByKey = {};

  /// Module load timing (ms)
  int _lastModuleLoadMs = 0;
  int _totalModuleLoads = 0;
  int _cumulativeModuleLoadMs = 0;

  /// Registry cache
  int _registryCacheHits = 0;
  int _registryCacheMisses = 0;

  /// Context resolution timing (ms)
  int _lastContextResolutionMs = 0;
  int _cumulativeContextResolutionMs = 0;
  int _totalContextResolutions = 0;

  /// Runtime sync latency (ms)
  int _lastSyncLatencyMs = 0;
  int _cumulativeSyncLatencyMs = 0;
  int _totalSyncLatencies = 0;

  // ─── RECORD METHODS ──────────────────────────────────────

  void recordSidebarBuild(int durationMs) {
    _lastSidebarBuildMs = durationMs;
    _totalSidebarBuilds++;
    _cumulativeSidebarBuildMs += durationMs;
    _maxSidebarBuildMs = max(_maxSidebarBuildMs, durationMs);
  }

  void recordBottomNavBuild(int durationMs) {
    _lastBottomNavBuildMs = durationMs;
    _totalBottomNavBuilds++;
    _cumulativeBottomNavBuildMs += durationMs;
    _maxBottomNavBuildMs = max(_maxBottomNavBuildMs, durationMs);
  }

  void recordDashboardRender(int durationMs) {
    _lastDashboardRenderMs = durationMs;
    _totalDashboardRenders++;
    _cumulativeDashboardRenderMs += durationMs;
    _maxDashboardRenderMs = max(_maxDashboardRenderMs, durationMs);
  }

  void recordWidgetFailure(String widgetKey) {
    _widgetFailureCount++;
    _widgetFailuresByKey[widgetKey] =
        (_widgetFailuresByKey[widgetKey] ?? 0) + 1;
  }

  void recordModuleLoad(int durationMs) {
    _lastModuleLoadMs = durationMs;
    _totalModuleLoads++;
    _cumulativeModuleLoadMs += durationMs;
  }

  void recordRegistryCacheHit() {
    _registryCacheHits++;
  }

  void recordRegistryCacheMiss() {
    _registryCacheMisses++;
  }

  void recordContextResolution(int durationMs) {
    _lastContextResolutionMs = durationMs;
    _totalContextResolutions++;
    _cumulativeContextResolutionMs += durationMs;
  }

  void recordSyncLatency(int durationMs) {
    _lastSyncLatencyMs = durationMs;
    _totalSyncLatencies++;
    _cumulativeSyncLatencyMs += durationMs;
  }

  // ─── GETTERS ─────────────────────────────────────────────

  // Sidebar
  int get lastSidebarBuildMs => _lastSidebarBuildMs;
  double get avgSidebarBuildMs => _totalSidebarBuilds > 0
      ? _cumulativeSidebarBuildMs / _totalSidebarBuilds
      : 0;
  int get maxSidebarBuildMs => _maxSidebarBuildMs;
  int get totalSidebarBuilds => _totalSidebarBuilds;

  // Bottom Nav
  int get lastBottomNavBuildMs => _lastBottomNavBuildMs;
  double get avgBottomNavBuildMs => _totalBottomNavBuilds > 0
      ? _cumulativeBottomNavBuildMs / _totalBottomNavBuilds
      : 0;
  int get maxBottomNavBuildMs => _maxBottomNavBuildMs;
  int get totalBottomNavBuilds => _totalBottomNavBuilds;

  // Dashboard
  int get lastDashboardRenderMs => _lastDashboardRenderMs;
  double get avgDashboardRenderMs => _totalDashboardRenders > 0
      ? _cumulativeDashboardRenderMs / _totalDashboardRenders
      : 0;
  int get maxDashboardRenderMs => _maxDashboardRenderMs;
  int get totalDashboardRenders => _totalDashboardRenders;

  // Widget failures
  int get widgetFailureCount => _widgetFailureCount;
  Map<String, int> get widgetFailuresByKey =>
      Map.unmodifiable(_widgetFailuresByKey);

  // Module load
  int get lastModuleLoadMs => _lastModuleLoadMs;
  double get avgModuleLoadMs => _totalModuleLoads > 0
      ? _cumulativeModuleLoadMs / _totalModuleLoads
      : 0;
  int get totalModuleLoads => _totalModuleLoads;

  // Registry cache
  int get registryCacheHits => _registryCacheHits;
  int get registryCacheMisses => _registryCacheMisses;
  double get registryCacheHitRate {
    final total = _registryCacheHits + _registryCacheMisses;
    return total > 0 ? _registryCacheHits / total : 0;
  }

  // Context resolution
  int get lastContextResolutionMs => _lastContextResolutionMs;
  double get avgContextResolutionMs => _totalContextResolutions > 0
      ? _cumulativeContextResolutionMs / _totalContextResolutions
      : 0;
  int get totalContextResolutions => _totalContextResolutions;

  // Sync latency
  int get lastSyncLatencyMs => _lastSyncLatencyMs;
  double get avgSyncLatencyMs => _totalSyncLatencies > 0
      ? _cumulativeSyncLatencyMs / _totalSyncLatencies
      : 0;
  int get totalSyncLatencies => _totalSyncLatencies;

  // ─── RESET ───────────────────────────────────────────────

  void reset() {
    _lastSidebarBuildMs = 0;
    _lastBottomNavBuildMs = 0;
    _totalSidebarBuilds = 0;
    _totalBottomNavBuilds = 0;
    _cumulativeSidebarBuildMs = 0;
    _cumulativeBottomNavBuildMs = 0;
    _maxSidebarBuildMs = 0;
    _maxBottomNavBuildMs = 0;
    _lastDashboardRenderMs = 0;
    _totalDashboardRenders = 0;
    _cumulativeDashboardRenderMs = 0;
    _maxDashboardRenderMs = 0;
    _widgetFailureCount = 0;
    _widgetFailuresByKey.clear();
    _lastModuleLoadMs = 0;
    _totalModuleLoads = 0;
    _cumulativeModuleLoadMs = 0;
    _registryCacheHits = 0;
    _registryCacheMisses = 0;
    _lastContextResolutionMs = 0;
    _cumulativeContextResolutionMs = 0;
    _totalContextResolutions = 0;
    _lastSyncLatencyMs = 0;
    _cumulativeSyncLatencyMs = 0;
    _totalSyncLatencies = 0;
  }

  // ─── SNAPSHOT ────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'sidebar': {
          'lastBuildMs': _lastSidebarBuildMs,
          'avgBuildMs': avgSidebarBuildMs,
          'maxBuildMs': _maxSidebarBuildMs,
          'totalBuilds': _totalSidebarBuilds,
        },
        'bottomNav': {
          'lastBuildMs': _lastBottomNavBuildMs,
          'avgBuildMs': avgBottomNavBuildMs,
          'maxBuildMs': _maxBottomNavBuildMs,
          'totalBuilds': _totalBottomNavBuilds,
        },
        'dashboard': {
          'lastRenderMs': _lastDashboardRenderMs,
          'avgRenderMs': avgDashboardRenderMs,
          'maxRenderMs': _maxDashboardRenderMs,
          'totalRenders': _totalDashboardRenders,
        },
        'widgetFailures': {
          'total': _widgetFailureCount,
          'byKey': _widgetFailuresByKey,
        },
        'moduleLoad': {
          'lastLoadMs': _lastModuleLoadMs,
          'avgLoadMs': avgModuleLoadMs,
          'totalLoads': _totalModuleLoads,
        },
        'registryCache': {
          'hits': _registryCacheHits,
          'misses': _registryCacheMisses,
          'hitRate': registryCacheHitRate,
        },
        'contextResolution': {
          'lastMs': _lastContextResolutionMs,
          'avgMs': avgContextResolutionMs,
          'total': _totalContextResolutions,
        },
        'syncLatency': {
          'lastMs': _lastSyncLatencyMs,
          'avgMs': avgSyncLatencyMs,
          'total': _totalSyncLatencies,
        },
      };
}

/// Singleton instance for app-wide access
final navigationMetrics = NavigationMetrics();
