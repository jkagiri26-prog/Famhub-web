import 'dart:async';
import 'app_event_bus.dart';
import 'events.dart';

class AppEventListeners {
  final AppEventBus bus;

  StreamSubscription<AppEvent>? _sub;

  AppEventListeners(this.bus);

  void start() {
    _sub = bus.stream.listen((event) {
      _route(event);
    });
  }

  void _route(AppEvent event) {
    if (event is ModuleUpdatedEvent ||
        event is ModuleInstalledEvent) {
      _handleModuleEvent(event);
    }

    if (event is DashboardPatchEvent) {
      _handlePatch(event);
    }

    if (event is RuntimeSyncEvent) {
      _handleRuntime(event);
    }
  }

  void _handleModuleEvent(AppEvent event) {
    // OBSERVATION ONLY (NO MUTATION)
  }

  void _handlePatch(DashboardPatchEvent event) {
    // MUST BE REMOVED OR MOVED TO PIPELINE ONLY
  }

  void _handleRuntime(RuntimeSyncEvent event) {
    // telemetry only
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}