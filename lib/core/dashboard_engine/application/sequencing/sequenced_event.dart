class SequencedEvent {
  const SequencedEvent({
    required this.sequenceId,
    required this.entityId,
    required this.type,
    required this.payload,
    required this.timestamp,
  });

  final String sequenceId;

  final String entityId;
  final String type;
  final Map<String, dynamic> payload;

  final DateTime timestamp;
}