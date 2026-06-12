import 'dart:async';

import 'package:famhub_app/core/events/app_event_bus.dart';
import 'package:famhub_app/core/events/events.dart';

/// ============================================================
/// EVENT OBSERVER (OBSERVABILITY LAYER)
/// ============================================================
/// Passive system-wide telemetry for EventBus.
///
/// Responsibilities:
/// - Trace event flow
/// - Detect duplicates
/// - Record timing
/// - Provide debugging visibility
class EventObserver {
  EventObserver(this.bus);

  final AppEventBus bus;

  StreamSubscription<AppEvent>? _sub;

  final List<EventTrace> _traces = [];

  bool _enabled = true;

  /// ============================================================
  /// START OBSERVING
  /// ============================================================
  void start() {
    _sub = bus.stream.listen(_record);
  }

  /// ============================================================
  /// STOP OBSERVING
  /// ============================================================
  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  /// ============================================================
  /// RECORD EVENT
  /// ============================================================
  void _record(AppEvent event) {
    if (!_enabled) return;

    _traces.add(
      EventTrace(
        type: event.runtimeType.toString(),
        timestamp: event.timestamp,
        payload: _extractPayload(event),
      ),
    );

    /// Optional: prevent unbounded memory growth
    if (_traces.length > 5000) {
      _traces.removeAt(0);
    }
  }

  /// ============================================================
  /// PAYLOAD EXTRACTION (SAFE INTROSPECTION)
  /// ============================================================
  Map<String, dynamic> _extractPayload(AppEvent event) {
    if (event is ModuleUpdatedEvent) {
      return {
        "moduleId": event.moduleId,
        "payload": event.payload,
      };
    }

    if (event is ModuleInstalledEvent) {
      return {
        "moduleId": event.moduleId,
      };
    }

    if (event is DashboardPatchEvent) {
      return {
        "patchType": event.patch.runtimeType.toString(),
      };
    }

    if (event is RuntimeSyncEvent) {
      return {
        "type": event.type,
        "data": event.data,
      };
    }

    return {
      "unknown": true,
    };
  }

  /// ============================================================
  /// DEBUG ACCESS
  /// ============================================================
  List<EventTrace> get traces => List.unmodifiable(_traces);

  void clear() => _traces.clear();

  void disable() => _enabled = false;

  void enable() => _enabled = true;
}

/// ============================================================
/// EVENT TRACE MODEL
/// ============================================================
class EventTrace {
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  EventTrace({
    required this.type,
    required this.timestamp,
    required this.payload,
  });

  @override
  String toString() {
    return "[$timestamp] $type -> $payload";
  }
}