import 'package:famhub_app/core/events/app_event_bus.dart';

/// ============================================================
/// MODULE EVENTS
/// ============================================================

class ModuleUpdatedEvent extends AppEvent {
  final String moduleId;
  final Map<String, dynamic> payload;

  ModuleUpdatedEvent({
    required this.moduleId,
    required this.payload,
  });
}

class ModuleInstalledEvent extends AppEvent {
  final String moduleId;

  ModuleInstalledEvent({
    required this.moduleId,
  });
}

/// ============================================================
/// DASHBOARD EVENTS (SAFE NOTIFICATION ONLY)
/// ============================================================

/// ⚠️ IMPORTANT:
/// This MUST NOT carry domain objects (no DashboardRuntimePatch)
/// It is ONLY a signal that a patch exists elsewhere.
class DashboardPatchEvent extends AppEvent {
  /// Unique identifier of the patch produced by pipeline
  final String patchId;

  const DashboardPatchEvent(this.patchId);
}

/// ============================================================
/// RUNTIME EVENTS
/// ============================================================

class RuntimeSyncEvent extends AppEvent {
  final String type;
  final Map<String, dynamic> data;

  RuntimeSyncEvent({
    required this.type,
    required this.data,
  });
}

/// ============================================================
/// SYSTEM EVENTS
/// ============================================================

class SystemBootEvent extends AppEvent {
  final DateTime startedAt;

  SystemBootEvent() : startedAt = DateTime.now();
}

class SystemErrorEvent extends AppEvent {
  final String message;
  final Object? error;

  SystemErrorEvent({
    required this.message,
    this.error,
  });
}