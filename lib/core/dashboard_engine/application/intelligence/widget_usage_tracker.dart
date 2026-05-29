import '../events/dashboard_event_bus.dart';
import '../events/dashboard_refresh_event.dart';

/// ============================================================
/// WIDGET USAGE TRACKER (AI SIGNAL LAYER)
/// ============================================================
///
/// Collects user interaction signals for adaptive dashboard behavior.
///
/// Responsibilities:
/// - track widget usage
/// - emit events to event bus
/// - feed scoring engine indirectly
///
/// ❌ NOT responsible for:
/// - scoring
/// - layout decisions
/// - persistence logic (backend)
/// ============================================================
class WidgetUsageTracker {
  final DashboardEventBus eventBus;

  WidgetUsageTracker({
    required this.eventBus,
  });

  /// Track widget open event
  void trackOpen(String widgetKey) {
    eventBus.emit(
      DashboardRefreshEvent(
        type: DashboardRefreshEventType.moduleActivation,
        moduleKey: widgetKey,
        source: 'usage_tracker',
        metadata: const {
          'action': 'open',
        },
      ),
    );
  }

  /// Track widget interaction event
  void trackInteraction(String widgetKey) {
    eventBus.emit(
      DashboardRefreshEvent(
        type: DashboardRefreshEventType.moduleActivation,
        moduleKey: widgetKey,
        source: 'usage_tracker',
        metadata: const {
          'action': 'interaction',
        },
      ),
    );
  }
}