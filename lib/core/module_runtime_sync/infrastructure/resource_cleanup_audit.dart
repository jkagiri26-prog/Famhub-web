import 'dart:async';

/// ============================================================
/// PHASE 6 — TASK B3: RESOURCE CLEANUP AUDITS
/// ============================================================
///
/// Detects leaked subscriptions, timers, and lifecycle observers.
///
/// CHECKS:
/// - Realtime channels properly disposed
/// - Stream subscriptions cancelled
/// - Timers disposed
/// - Lifecycle observers removed
///
/// USAGE:
///   final audit = ResourceCleanupAudit();
///   audit.registerTimer('my-timer', myTimer);
///   // ... during dispose ...
///   audit.cancelTimer('my-timer');
///   // ... at audit time ...
///   final leaks = audit.findLeaks();
/// ============================================================
class ResourceCleanupAudit {
  final Map<String, Timer> _timers = {};
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, void Function()> _disposalCallbacks = {};
  final List<String> _lifecycleObservers = [];

  /// ============================================================
  /// REGISTER RESOURCES
  /// ============================================================
  void registerTimer(String id, Timer timer) {
    _timers[id] = timer;
  }

  void registerSubscription(String id, StreamSubscription sub) {
    _subscriptions[id] = sub;
  }

  void registerDisposalCallback(String id, void Function() dispose) {
    _disposalCallbacks[id] = dispose;
  }

  void registerLifecycleObserver(String id) {
    _lifecycleObservers.add(id);
  }

  /// ============================================================
  /// CANCEL/DISPOSE RESOURCES
  /// ============================================================
  void cancelTimer(String id) {
    _timers.remove(id)?.cancel();
  }

  void cancelSubscription(String id) {
    _subscriptions.remove(id)?.cancel();
  }

  void runDisposalCallback(String id) {
    final cb = _disposalCallbacks.remove(id);
    if (cb != null) cb();
  }

  void removeLifecycleObserver(String id) {
    _lifecycleObservers.remove(id);
  }

  /// ============================================================
  /// DISPOSE ALL
  /// ============================================================
  void disposeAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();

    for (final s in _subscriptions.values) {
      s.cancel();
    }
    _subscriptions.clear();

    for (final cb in _disposalCallbacks.values) {
      cb();
    }
    _disposalCallbacks.clear();

    _lifecycleObservers.clear();
  }

  /// ============================================================
  /// AUDIT — FIND LEAKS
  /// ============================================================
  ///
  /// Returns a map of resource types to lists of IDs that
  /// are still registered (i.e., not properly disposed).
  ///
  Map<String, List<String>> findLeaks() {
    final leaks = <String, List<String>>{};

    if (_timers.isNotEmpty) {
      leaks['timers'] = _timers.keys.toList();
    }
    if (_subscriptions.isNotEmpty) {
      leaks['subscriptions'] = _subscriptions.keys.toList();
    }
    if (_disposalCallbacks.isNotEmpty) {
      leaks['disposalCallbacks'] = _disposalCallbacks.keys.toList();
    }
    if (_lifecycleObservers.isNotEmpty) {
      leaks['lifecycleObservers'] = _lifecycleObservers;
    }

    return leaks;
  }

  /// Returns true if no leaks found
  bool get hasNoLeaks =>
      _timers.isEmpty &&
      _subscriptions.isEmpty &&
      _disposalCallbacks.isEmpty &&
      _lifecycleObservers.isEmpty;
}
