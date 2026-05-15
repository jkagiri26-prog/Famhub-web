enum QueueStatus { pending, syncing, success, failed }

class QueueItem {
  final String id;
  final String action; // e.g. "create_listing"
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final QueueStatus status;

  QueueItem({
    required this.id,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.status = QueueStatus.pending,
  });

  QueueItem copyWith({QueueStatus? status}) {
    return QueueItem(
      id: id,
      action: action,
      payload: payload,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}