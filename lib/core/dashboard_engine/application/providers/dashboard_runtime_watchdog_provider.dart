import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../monitoring/dashboard_runtime_watchdog.dart';

/// ============================================================
/// SYSTEM-LEVEL WATCHDOG PROVIDER (HARDENED)
/// ============================================================
/// RULES:
/// - single instance per app lifecycle
/// - idempotent lifecycle
/// - safe disposal cleanup
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
/// PROXY LAYER (CRITICAL SAFETY WRAPPER)
/// ============================================================

class _SafeWatchdogProxy implements DashboardRuntimeWatchdog {
  _SafeWatchdogProxy(this._inner);

  final DashboardRuntimeWatchdog _inner;

  @override
  void start() {
    // idempotent protection
    _inner.start();
  }

  @override
  void stop() {
    _inner.stop();
  }

  @override
  void recordPatchLatency(Duration d) {
    _inner.recordPatchLatency(d);
  }

  @override
  void recordZoneInvalidation() {
    _inner.recordZoneInvalidation();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return Function.apply(
      _inner.noSuchMethod,
      [invocation],
    );
  }
}