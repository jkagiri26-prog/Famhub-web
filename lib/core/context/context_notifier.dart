import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_context.dart';

class ContextNotifier extends StateNotifier<AppContext> {
  ContextNotifier() : super(AppContext.empty);

  void setUser(String userId, {String? entityId}) {
    state = state.copyWith(
      user: state.user.copyWith(
        userId: userId,
        entityId: entityId,
      ),
    );
  }

  void setRole(UserRole role) {
    state = state.copyWith(
      role: RoleContext(activeRole: role),
    );
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void reset() {
    state = AppContext.empty;
  }
}