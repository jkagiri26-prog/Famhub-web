class EntityContext {
  final String? userId;
  final String? role;
  final String? entityId;
  final String? tier;
  final bool isGuest;
  final bool isLoading;

  const EntityContext({
    this.userId,
    this.role,
    this.entityId,
    this.tier,
    this.isGuest = true,
    this.isLoading = true,
  });

  EntityContext copyWith({
    String? userId,
    String? role,
    String? entityId,
    String? tier,
    bool? isGuest,
    bool? isLoading,
  }) {
    return EntityContext(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      entityId: entityId ?? this.entityId,
      tier: tier ?? this.tier,
      isGuest: isGuest ?? this.isGuest,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static const empty = EntityContext();
}