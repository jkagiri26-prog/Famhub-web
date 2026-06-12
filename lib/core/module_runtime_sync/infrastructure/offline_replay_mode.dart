import 'dart:async';

/// ============================================================
/// PHASE 6 — TASK E2: OFFLINE REPLAY MODE
/// ============================================================
///
/// Supports temporary offline operation by deferring replay
/// until connectivity is restored.
///
/// BEHAVIOR:
/// - While offline, journal continues accepting locally-generated events
/// - Replay is deferred until reconnect
/// - Replay is automatically triggered on reconnect
/// - No corruption during reconnect merge
///
/// USAGE:
///   final mode = OfflineReplayMode();
///   mode.onDisconnected();
///   // ... journal continues accepting events ...
///   mode.onReconnected(() => engine.replayDelta());
/// ============================================================
class OfflineReplayMode {
  bool _isOffline = false;
  bool _pendingReplay = false;

  /// Whether the engine is currently offline
  bool get isOffline => _isOffline;

  /// Whether replay is pending due to offline mode
  bool get hasPendingReplay => _pendingReplay;

  /// Called when network connectivity is lost
  void onDisconnected() {
    _isOffline = true;
  }

  /// Called when network connectivity is restored.
  /// [onReplay] is the callback to trigger deferred replay.
  Future<void> onReconnected(Future<void> Function() onReplay) async {
    if (!_isOffline) return;

    _isOffline = false;

    if (_pendingReplay) {
      _pendingReplay = false;
      await onReplay();
    }
  }

  /// When offline, marks that replay is pending.
  /// When online, immediately triggers replay.
  Future<void> requestReplay(Future<void> Function() onReplay) async {
    if (_isOffline) {
      _pendingReplay = true;
      return;
    }

    await onReplay();
  }

  /// Reset state
  void reset() {
    _isOffline = false;
    _pendingReplay = false;
  }
}
