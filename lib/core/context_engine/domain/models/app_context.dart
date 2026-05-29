class AppContext {
  final String? userId;
  final String? entityId;
  final String role;
  final bool isLoading;

  const AppContext({
    required this.userId,
    required this.entityId,
    required this.role,
    required this.isLoading,
  });

  factory AppContext.fromEntity(EntityContext ctx) {
    return AppContext(
      userId: ctx.userId,
      entityId: ctx.entityId,
      role: ctx.role,
      isLoading: ctx.isLoading,
    );
  }
}