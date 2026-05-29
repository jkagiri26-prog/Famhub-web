enum DashboardRefreshEventType {
  moduleActivation,
  featureFlagUpdate,
  notificationTriggered,
  approvalWorkflowUpdate,
  entitySwitch,
  roleContextChange,
}

class DashboardRefreshEvent {
  final DashboardRefreshEventType type;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  DashboardRefreshEvent({
    required this.type,
    required this.metadata,
  }) : timestamp = DateTime.now();

  @override
  String toString() =>
      'DashboardRefreshEvent(type: $type, timestamp: $timestamp, metadata: $metadata)';
}
