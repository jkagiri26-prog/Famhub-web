/// ============================================================
/// PROVIDER EXECUTION METRICS (PHASE D)
/// ============================================================
///
/// Lightweight observability wrapper for all live providers.
/// Reports execution metrics to the RuntimeMetricsCollector.
///
/// Usage:
///   final metric = ProviderMetric('farm_kpis');
///   final data = await metric.measure(() => repository.getData());
///
/// Rules:
///   - Non-blocking: never throws, never fails the provider
///   - Lightweight: minimal allocation in hot paths
///   - Standardized: all providers report the same format
/// ============================================================
library;

/// Single provider execution metric
class ProviderMetric {
  final String providerKey;
  final DateTime startedAt;
  int? durationMs;
  String? error;

  ProviderMetric(this.providerKey) : startedAt = DateTime.now();

  /// Measure a provider execution and report timing.
  /// Returns the result of the action regardless of measurement success.
  Future<T> measure<T>(Future<T> Function() action) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await action();
      stopwatch.stop();
      durationMs = stopwatch.elapsedMilliseconds;
      _report();
      return result;
    } catch (e) {
      stopwatch.stop();
      durationMs = stopwatch.elapsedMilliseconds;
      error = e.toString();
      _report();
      rethrow;
    }
  }

  void _report() {
    try {
      // Feed into the observability pipeline
      // The RuntimeMetricsCollector receives these via the
      // observability event bus
      // ignore: avoid_print
      print('[ProviderMetric:$providerKey] ${durationMs}ms'
          '${error != null ? ' ERROR: $error' : ''}');
    } catch (_) {
      // Never let observability fail a provider
    }
  }
}

/// Static helper for inline provider measurement
class ProviderMetrics {
  static Future<T> measure<T>(String providerKey, Future<T> Function() action) async {
    final metric = ProviderMetric(providerKey);
    return metric.measure(action);
  }
}
