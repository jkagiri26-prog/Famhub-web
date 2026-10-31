class EntityContext {
  /// auth.users.id
  final String? userId;

  /// users.profiles.id — distinct from userId (auth.users.id)
  final String? profileId;

  /// Workspace ID from the active core.entity_context_sessions row.
  final String? activeWorkspaceId;

  /// core.entities.id — the active entity. Null when unavailable; never
  /// fabricated.
  final String? entityId;

  /// core.user_roles.id — the active role id. Distinct from [role].
  final String? roleId;

  /// commerce.business_profiles.id for the active entity (nullable).
  final String? businessProfileId;

  /// Operational role/mode (e.g. 'farmer', 'trader'). Null when unknown.
  final String? role;

  final String? tier;
  final bool isGuest;
  final bool isLoading;

  const EntityContext({
    this.userId,
    this.profileId,
    this.activeWorkspaceId,
    this.entityId,
    this.roleId,
    this.businessProfileId,
    this.role,
    this.tier,
    this.isGuest = true,
    this.isLoading = true,
  });

  EntityContext copyWith({
    String? userId,
    String? profileId,
    String? activeWorkspaceId,
    String? entityId,
    String? roleId,
    String? businessProfileId,
    String? role,
    String? tier,
    bool? isGuest,
    bool? isLoading,
    bool clearUserId = false,
    bool clearProfileId = false,
    bool clearActiveWorkspaceId = false,
    bool clearEntityId = false,
    bool clearRoleId = false,
    bool clearBusinessProfileId = false,
    bool clearRole = false,
  }) {
    return EntityContext(
      userId: clearUserId ? null : userId ?? this.userId,
      profileId: clearProfileId ? null : profileId ?? this.profileId,
      activeWorkspaceId: clearActiveWorkspaceId
          ? null
          : activeWorkspaceId ?? this.activeWorkspaceId,
      entityId: clearEntityId ? null : entityId ?? this.entityId,
      roleId: clearRoleId ? null : roleId ?? this.roleId,
      businessProfileId: clearBusinessProfileId
          ? null
          : businessProfileId ?? this.businessProfileId,
      role: clearRole ? null : role ?? this.role,
      tier: tier ?? this.tier,
      isGuest: isGuest ?? this.isGuest,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static const empty = EntityContext();
}
