import 'user_context.dart';
import 'role_context.dart';

class AppContext {
  final UserContext user;
  final RoleContext role;
  final bool isLoading;

  const AppContext({
    required this.user,
    required this.role,
    this.isLoading = false,
  });

  static const empty = AppContext(
    user: UserContext.empty,
    role: RoleContext.defaultRole,
  );

  AppContext copyWith({
    UserContext? user,
    RoleContext? role,
    bool? isLoading,
  }) {
    return AppContext(
      user: user ?? this.user,
      role: role ?? this.role,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}