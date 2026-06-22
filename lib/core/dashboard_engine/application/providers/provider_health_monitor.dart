/// ============================================================
/// PROVIDER HEALTH MONITOR — PHASE 3
/// ============================================================
///
/// PURPOSE:
/// Tracks the health and lifecycle state of critical Riverpod
/// providers in the dashboard engine. Enables cross-provider
/// health monitoring, dependency tracking, and diagnostics.
///
/// RESPONSIBILITIES:
/// - Track provider initialization state
/// - Monitor provider failure rates
/// - Detect stale or orphaned providers
/// - Expose health snapshots for diagnostics
///
/// NON-RESPONSIBILITIES:
/// - Managing provider lifecycle (Riverpod handles this)
/// - Replacing existing provider infrastructure
/// - UI rendering (consumed by diagnostics layer)
///
/// 🧠 LOCATION CONTEXT:
///   core/dashboard_engine/application/providers/
///
/// ✅ USAGE:
/// ```dart
/// // Register a provider for health monitoring
/// ProviderHealthMonitor.instance.register(
///   name: 'dashboardRuntimeValidator',
///   dependencies: ['contextProvider', 'moduleRuntimeSyncProvider'],
/// );
///
/// // Record success/failure
/// ProviderHealthMonitor.instance.recordSuccess('dashboardRuntimeValidator');
/// ProviderHealthMonitor.instance.recordFailure('dashboardRuntimeValidator', error);
/// ```
/// ============================================================

// ignore_for_file: dangling_library_doc_comments

/// Health state of a single provider
class ProviderHealthEntry {
  final String name;
  final List<String> dependencies;
  int successCount;
  int failureCount;
  DateTime? lastAccessedAt;
  DateTime? lastErrorAt;
  String? lastError;
  bool isInitialized;

  ProviderHealthEntry({
    required this.name,
    this.dependencies = const [],
    this.successCount = 0,
    this.failureCount = 0,
    this.lastAccessedAt,
    this.lastErrorAt,
    this.lastError,
    this.isInitialized = false,
  });

  double get healthIndex {
    final total = successCount + failureCount;
    if (total == 0) return 1.0;
    return successCount / total;
  }

  bool get isHealthy => healthIndex > 0.9 && isInitialized;
  bool get isDegraded => healthIndex > 0.5 && isInitialized;
  bool get isCritical => !isHealthy && !isDegraded;

  Map<String, dynamic> toJson() => {
        'name': name,
        'dependencies': dependencies,
        'successCount': successCount,
        'failureCount': failureCount,
        'healthIndex': healthIndex,
        'isInitialized': isInitialized,
        'lastAccessedAt': lastAccessedAt?.toIso8601String(),
        'lastErrorAt': lastErrorAt?.toIso8601String(),
        'lastError': lastError,
        'status': isHealthy ? 'healthy' : isDegraded ? 'degraded' : 'critical',
      };
}

/// Aggregate health snapshot of all monitored providers
class ProviderHealthSnapshot {
  final Map<String, ProviderHealthEntry> entries;
  final DateTime snapshotAt;

  const ProviderHealthSnapshot({
    required this.entries,
    required this.snapshotAt,
  });

  int get healthyCount => entries.values.where((e) => e.isHealthy).length;
  int get degradedCount => entries.values.where((e) => e.isDegraded).length;
  int get criticalCount => entries.values.where((e) => e.isCritical).length;

  bool get allHealthy => entries.values.every((e) => e.isHealthy);

  List<ProviderHealthEntry> get unhealthyProviders =>
      entries.values.where((e) => !e.isHealthy).toList();

  Map<String, dynamic> toJson() => {
        'snapshotAt': snapshotAt.toIso8601String(),
        'healthyCount': healthyCount,
        'degradedCount': degradedCount,
        'criticalCount': criticalCount,
        'allHealthy': allHealthy,
        'providers': entries.map((k, v) => MapEntry(k, v.toJson())),
      };
}

/// Singleton health monitor for the provider graph
class ProviderHealthMonitor {
  ProviderHealthMonitor._internal();
  static final ProviderHealthMonitor instance = ProviderHealthMonitor._internal();

  final Map<String, ProviderHealthEntry> _providers = {};

  /// Register a provider for health tracking
  void register({
    required String name,
    List<String> dependencies = const [],
  }) {
    _providers.putIfAbsent(
      name,
      () => ProviderHealthEntry(
        name: name,
        dependencies: dependencies,
      ),
    );
  }

  /// Record a successful provider resolution
  void recordSuccess(String name) {
    final entry = _providers[name];
    if (entry != null) {
      entry.successCount++;
      entry.lastAccessedAt = DateTime.now();
      entry.isInitialized = true;
    }
  }

  /// Record a provider failure
  void recordFailure(String name, Object error) {
    final entry = _providers[name];
    if (entry != null) {
      entry.failureCount++;
      entry.lastErrorAt = DateTime.now();
      entry.lastError = error.toString();
    }
  }

  /// Get health for a specific provider
  ProviderHealthEntry? getProvider(String name) => _providers[name];

  /// Get current health snapshot
  ProviderHealthSnapshot get snapshot => ProviderHealthSnapshot(
        entries: Map.unmodifiable(_providers),
        snapshotAt: DateTime.now(),
      );

  /// Check if all registered providers are healthy
  bool get allHealthy => _providers.values.every((e) => e.isHealthy);

  /// Get unhealthy provider names
  List<String> get unhealthyProviders =>
      _providers.values
          .where((e) => !e.isHealthy)
          .map((e) => e.name)
          .toList();

  /// Get critical provider names
  List<String> get criticalProviders =>
      _providers.values
          .where((e) => e.isCritical)
          .map((e) => e.name)
          .toList();

  /// Reset all health entries
  void reset() {
    _providers.clear();
  }

  /// Remove a provider from monitoring
  void unregister(String name) {
    _providers.remove(name);
  }
}
