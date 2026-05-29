import 'dart:async';

import 'dashboard_usage_sync_service.dart';

class DashboardUsageTracker {
  final DashboardUsageSyncService? syncService;

  DashboardUsageTracker({
    this.syncService,
  });

  final Map<String, _UsageData> _store = {};

  /// Track widget open
  void trackOpen(
    String widgetKey, {
    String? moduleKey,
    String? entityId,
  }) {
    final current = _store[widgetKey] ?? _UsageData();

    final updated = current.copyWith(
      openCount: current.openCount + 1,
      lastAccessed: DateTime.now(),
    );

    _store[widgetKey] = updated;

    _queueSync(
      widgetKey,
      'open',
      moduleKey,
      entityId,
    );
  }

  /// Track interaction
  void trackInteraction(
    String widgetKey, {
    String? moduleKey,
    String? entityId,
  }) {
    final current = _store[widgetKey] ?? _UsageData();

    final updated = current.copyWith(
      interactionCount: current.interactionCount + 1,
      lastAccessed: DateTime.now(),
    );

    _store[widgetKey] = updated;

    _queueSync(
      widgetKey,
      'interaction',
      moduleKey,
      entityId,
    );
  }

  /// AI score used by optimizer
  double score(String widgetKey) {
    final data = _store[widgetKey];
    if (data == null) return 0;

    return (data.openCount * 2) +
        (data.interactionCount * 3);
  }

  /// =========================
  /// BACKEND SYNC TRIGGER
  /// =========================
  void _queueSync(
    String widgetKey,
    String eventType,
    String? moduleKey,
    String? entityId,
  ) {
    final service = syncService;
    if (service == null) return;

    /// async fire-and-forget (non-blocking UI)
    Future.microtask(() {
      service.syncEvent(
        widgetKey: widgetKey,
        eventType: eventType,
        moduleKey: moduleKey,
        entityId: entityId,
      );
    });
  }

  /// cleanup old memory
  void decayOldData({Duration maxAge = const Duration(days: 30)}) {
    final now = DateTime.now();

    _store.removeWhere((_, data) {
      return now.difference(data.lastAccessed) > maxAge;
    });
  }
}

class _UsageData {
  final int openCount;
  final int interactionCount;
  final DateTime lastAccessed;

  _UsageData({
    this.openCount = 0,
    this.interactionCount = 0,
    DateTime? lastAccessed,
  }) : lastAccessed = lastAccessed ?? DateTime.now();

  _UsageData copyWith({
    int? openCount,
    int? interactionCount,
    DateTime? lastAccessed,
  }) {
    return _UsageData(
      openCount: openCount ?? this.openCount,
      interactionCount: interactionCount ?? this.interactionCount,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }
}