import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/dashboard_refresh_event.dart';

/// ============================================================
/// DASHBOARD EVENT STREAM PROVIDER
/// ============================================================
///
/// This provider manages event-driven updates to the dashboard.
///
/// Supported Events:
/// - Module activation/deactivation
/// - Feature flag updates
/// - Notification triggers
/// - Approval workflow updates
/// - Entity context switches
/// - Role context changes
///
/// Usage:
/// final events = ref.watch(dashboardEventStreamProvider);
/// ============================================================

class DashboardEventNotifier
    extends StateNotifier<Stream<DashboardRefreshEvent>> {
  DashboardEventNotifier() : super(_createEventStream());

  static Stream<DashboardRefreshEvent> _createEventStream() async* {
    // Event stream generator
    // This will be populated by refresh events from the renderer service
    // and other system components
  }

  void addEvent(DashboardRefreshEvent event) {
    // Events are added through the renderer service
  }
}

final dashboardEventStreamProvider =
    StateNotifierProvider<DashboardEventNotifier, Stream<DashboardRefreshEvent>>(
  (ref) => DashboardEventNotifier(),
);

/// ============================================================
/// MODULE ACTIVATION EVENT PROVIDER
/// ============================================================

final moduleActivationEventProvider =
    StreamProvider<String>((ref) async* {
  final eventStream = ref.watch(dashboardEventStreamProvider);
  await for (final event in eventStream) {
    if (event.type == DashboardRefreshEventType.moduleActivation) {
      yield event.metadata['moduleKey'] as String;
    }
  }
});

/// ============================================================
/// FEATURE FLAG UPDATE EVENT PROVIDER
/// ============================================================

final featureFlagUpdateEventProvider =
    StreamProvider<Map<String, bool>>((ref) async* {
  final eventStream = ref.watch(dashboardEventStreamProvider);
  await for (final event in eventStream) {
    if (event.type == DashboardRefreshEventType.featureFlagUpdate) {
      yield {
        event.metadata['featureFlagKey'] as String:
            event.metadata['enabled'] as bool,
      };
    }
  }
});

/// ============================================================
/// ENTITY SWITCH EVENT PROVIDER
/// ============================================================

final entitySwitchEventProvider =
    StreamProvider<String>((ref) async* {
  final eventStream = ref.watch(dashboardEventStreamProvider);
  await for (final event in eventStream) {
    if (event.type == DashboardRefreshEventType.entitySwitch) {
      yield event.metadata['entityId'] as String;
    }
  }
});

/// ============================================================
/// ROLE CONTEXT CHANGE EVENT PROVIDER
/// ============================================================

final roleContextChangeEventProvider =
    StreamProvider<String>((ref) async* {
  final eventStream = ref.watch(dashboardEventStreamProvider);
  await for (final event in eventStream) {
    if (event.type == DashboardRefreshEventType.roleContextChange) {
      yield event.metadata['roleContext'] as String;
    }
  }
});

/// ============================================================
/// NOTIFICATION TRIGGERED EVENT PROVIDER
/// ============================================================

final notificationTriggeredEventProvider =
    StreamProvider<Map<String, dynamic>>((ref) async* {
  final eventStream = ref.watch(dashboardEventStreamProvider);
  await for (final event in eventStream) {
    if (event.type == DashboardRefreshEventType.notificationTriggered) {
      yield event.metadata;
    }
  }
});

/// ============================================================
/// APPROVAL WORKFLOW UPDATE EVENT PROVIDER
/// ============================================================

final approvalWorkflowUpdateEventProvider =
    StreamProvider<Map<String, String>>((ref) async* {
  final eventStream = ref.watch(dashboardEventStreamProvider);
  await for (final event in eventStream) {
    if (event.type == DashboardRefreshEventType.approvalWorkflowUpdate) {
      yield {
        'workflowId': event.metadata['workflowId'] as String,
        'status': event.metadata['status'] as String,
      };
    }
  }
});
