import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/monitoring/dashboard_runtime_watchdog.dart';

/// ============================================================
/// SYSTEM-LEVEL WATCHDOG PROVIDER (HARDENED)
/// ============================================================
/// RULES:
/// - single instance per app lifecycle
/// - explicit delegation only
/// - no dynamic fallback
/// ============================================================

final dashboardRuntimeWatchdogProvider =
    Provider<DashboardRuntimeWatchdog>((ref) {
  final watchdog = DashboardRuntimeWatchdog(ref: ref);

  bool disposed = false;

  ref.onDispose(() {
    if (disposed) return;
    disposed = true;

    watchdog.stop();
  });

  return _SafeWatchdogProxy(watchdog);
});

/// ============================================================
/// STRICT PROXY (EXPLICIT DELEGATION ONLY)
/// ============================================================

class _SafeWatchdogProxy implements DashboardRuntimeWatchdog {
  _SafeWatchdogProxy(this._inner);

  final DashboardRuntimeWatchdog _inner;

  @override
  void start() => _inner.start();

  @override
  void stop() => _inner.stop();

  @override
  void recordPatchLatency(Duration d) {
    _inner.recordPatchLatency(d);
  }
}
