enum UserRole {
  farmer,
  trader,
  admin,
  extensionOfficer,
}

class RoleContext {
  final UserRole activeRole;

  const RoleContext({
    required this.activeRole,
  });

  static const defaultRole = RoleContext(activeRole: UserRole.farmer);

  RoleContext copyWith({
    UserRole? activeRole,
  }) {
    return RoleContext(
      activeRole: activeRole ?? this.activeRole,
    );
  }
}