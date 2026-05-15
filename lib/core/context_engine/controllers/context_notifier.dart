class ContextNotifier extends StateNotifier<EntityContext> {
  ContextNotifier() : super(const EntityContext());

  void setUser(String userId) {
    state = state.copyWith(userId: userId, isGuest: false);
  }

  void switchRole(String role) {
    state = state.copyWith(role: role);
  }

  void switchEntity(String entityId) {
    state = state.copyWith(entityId: entityId);
  }

  void logout() {
    state = const EntityContext();
  }
}