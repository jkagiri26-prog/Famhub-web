class UserContext {
  final String userId;
  final String? entityId;

  const UserContext({
    required this.userId,
    this.entityId,
  });

  static const empty = UserContext(userId: '');

  bool get isEmpty => userId.isEmpty;

  UserContext copyWith({
    String? userId,
    String? entityId,
  }) {
    return UserContext(
      userId: userId ?? this.userId,
      entityId: entityId ?? this.entityId,
    );
  }
}