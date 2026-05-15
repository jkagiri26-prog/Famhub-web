class AdminAction {
  final String actionType;
  final String targetKey;
  final String performedBy;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const AdminAction({
    required this.actionType,
    required this.targetKey,
    required this.performedBy,
    required this.createdAt,
    this.metadata,
  });

  factory AdminAction.fromMap(Map<String, dynamic> map) {
    return AdminAction(
      actionType: map['action_type'] ?? '',
      targetKey: map['target_key'] ?? '',
      performedBy: map['performed_by'] ?? '',
      createdAt: DateTime.parse(
        map['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action_type': actionType,
      'target_key': targetKey,
      'performed_by': performedBy,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}