/// ============================================================
/// ADMIN CONSOLE — PERMISSION KEYS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/domain/permissions/ = permission catalog
///
/// ✅ Responsibilities:
///   - Declare the permission keys used by the Admin dashboard
///     capability descriptors.
///   - Keep platform-administration and entity-administration
///     permissions in distinct namespaces so a user can hold one
///     without the other.
///
/// ❌ Does NOT:
///   - Grant any permission. These are contract identifiers only.
///   - Evaluate access. Evaluation is owned by the backend access
///     policy + RuntimeDecisionEngine.
/// ============================================================
library;

/// Permission identifiers for Admin capabilities.
///
/// The `admin.*` namespace covers FAMHUB platform administration.
/// The `entity.*` namespace covers administration of the active
/// organisation/entity. The backend access policy is the only
/// authority that grants these to a role.
class AdminPermissions {
  AdminPermissions._();

  // ── Platform administration ──────────────────────────────
  static const String platformOverview = 'admin.view';
  static const String users = 'admin.users.manage';
  static const String organisations = 'admin.organisations.manage';
  static const String workspaces = 'admin.workspaces.manage';
  static const String modules = 'admin.modules.manage';
  static const String featureFlags = 'admin.feature_flags.manage';
  static const String accessRules = 'admin.access_rules.manage';
  static const String roles = 'admin.roles.manage';
  static const String subscriptions = 'admin.subscriptions.manage';
  static const String workflows = 'admin.workflows.manage';
  static const String analytics = 'admin.analytics.view';
  static const String audit = 'admin.audit.view';
  static const String systemSettings = 'admin.configure';

  // ── Entity administration ────────────────────────────────
  static const String entityOverview = 'entity.view';
  static const String entityMembers = 'entity.members.manage';
  static const String entityRoles = 'entity.roles.manage';
  static const String entityWorkspaceAccess =
      'entity.workspace_access.manage';
  static const String entityModuleAccess = 'entity.module_access.manage';
  static const String entityProfile = 'entity.profile.manage';
  static const String entityBusinessProfiles =
      'entity.business_profiles.manage';
  static const String entityApprovals = 'entity.approvals.manage';
  static const String entityAuditTrail = 'entity.audit.view';
  static const String entitySettings = 'entity.configure';
}
