@immutable
class DashboardRefreshEvent {
  final DashboardRefreshEventType type;
  final DateTime timestamp;
  final String? moduleKey;
  final String? source;
  final Map<String, dynamic> metadata;

  const DashboardRefreshEvent({
    required this.type,
    required this.metadata,
    this.moduleKey,
    this.source,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  bool operator ==(Object other) {
    return other is DashboardRefreshEvent &&
        other.type == type &&
        other.moduleKey == moduleKey &&
        other.source == source &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(type, moduleKey, source, timestamp);

  @override
  String toString() =>
      'DashboardRefreshEvent(type: $type, moduleKey: $moduleKey, source: $source, timestamp: $timestamp)';
}