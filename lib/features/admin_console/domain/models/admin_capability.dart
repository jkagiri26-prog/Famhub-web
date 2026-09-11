/// ============================================================
/// ADMIN CAPABILITY — DESCRIPTOR MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/admin_console/domain/models/ = domain descriptors
///
/// ✅ Responsibilities:
///   - Describe the Admin dashboard sections as capabilities.
///   - Bind each section to a backend permission key and to a
///     scope (platform administration vs entity administration).
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Pure declarative descriptors. No runtime evaluation here.
///   - Descriptors are NOT visible actions. Visibility is decided
///     at runtime by the existing context/permission infrastructure.
///   - No statistics, counts, or fabricated data.
///
/// ❌ Does NOT:
///   - Grant access.
///   - Import Flutter UI (icon keys are resolved in presentation).
///   - Contain navigation/management operations (later phase).
/// ============================================================
library;

import 'package:famhub_app/features/admin_console/domain/permissions/permissions.dart';

/// Which administration layer a capability belongs to.
enum AdminScope {
  /// Manages FAMHUB itself (users, organisations, modules, billing...).
  platform,

  /// Manages the active organisation/entity (members, entity settings...).
  entity,
}

/// A single Admin dashboard capability descriptor.
class AdminCapability {
  /// Stable descriptor key (UI identity only — not a permission).
  final String key;

  /// Human-readable section label.
  final String label;

  /// Concise description of what the section governs.
  final String description;

  /// Generic icon key resolved via `IconResolver` in presentation.
  final String iconKey;

  /// Whether this section belongs to platform or entity administration.
  final AdminScope scope;

  /// Backend permission key required to render this capability.
  ///
  /// This is a contract identifier only. The backend access policy
  /// decides whether the active role is granted it.
  final String permissionKey;

  const AdminCapability({
    required this.key,
    required this.label,
    required this.description,
    required this.iconKey,
    required this.scope,
    required this.permissionKey,
  });
}

/// ============================================================
/// ADMIN CAPABILITY CATALOG
/// ============================================================
///
/// The initial Admin dashboard structure. Every entry is a
/// capability descriptor — never an unconditional visible action.
/// ============================================================
class AdminCapabilityCatalog {
  AdminCapabilityCatalog._();

  /// Platform administration capabilities.
  static const List<AdminCapability> platform = [
    AdminCapability(
      key: 'platform_overview',
      label: 'Overview',
      description: 'Platform-wide status and governance summary.',
      iconKey: 'dashboard',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.platformOverview,
    ),
    AdminCapability(
      key: 'platform_users',
      label: 'Users',
      description: 'Manage platform user accounts and access.',
      iconKey: 'people',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.users,
    ),
    AdminCapability(
      key: 'platform_organisations',
      label: 'Organisations',
      description: 'Manage organisations and their entities.',
      iconKey: 'business',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.organisations,
    ),
    AdminCapability(
      key: 'platform_workspaces',
      label: 'Workspaces',
      description: 'Manage the workspace catalog and types.',
      iconKey: 'widgets',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.workspaces,
    ),
    AdminCapability(
      key: 'platform_modules',
      label: 'Modules',
      description: 'Manage system modules and activation.',
      iconKey: 'list_alt',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.modules,
    ),
    AdminCapability(
      key: 'platform_feature_flags',
      label: 'Feature Flags',
      description: 'Control runtime feature availability.',
      iconKey: 'bolt',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.featureFlags,
    ),
    AdminCapability(
      key: 'platform_access_rules',
      label: 'Access Rules',
      description: 'Define platform access constraints.',
      iconKey: 'lock',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.accessRules,
    ),
    AdminCapability(
      key: 'platform_roles',
      label: 'Roles & Permissions',
      description: 'Manage roles and permission mappings.',
      iconKey: 'verified',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.roles,
    ),
    AdminCapability(
      key: 'platform_subscriptions',
      label: 'Subscriptions & Billing',
      description: 'Manage subscription tiers and billing.',
      iconKey: 'finance',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.subscriptions,
    ),
    AdminCapability(
      key: 'platform_workflows',
      label: 'Workflows',
      description: 'Manage platform workflows and automation.',
      iconKey: 'track_changes',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.workflows,
    ),
    AdminCapability(
      key: 'platform_analytics',
      label: 'Analytics & KPIs',
      description: 'Platform analytics and key indicators.',
      iconKey: 'analytics',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.analytics,
    ),
    AdminCapability(
      key: 'platform_audit',
      label: 'Audit & Governance',
      description: 'Review audit trails and governance records.',
      iconKey: 'history',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.audit,
    ),
    AdminCapability(
      key: 'platform_settings',
      label: 'System Settings',
      description: 'Manage platform-wide configuration.',
      iconKey: 'settings',
      scope: AdminScope.platform,
      permissionKey: AdminPermissions.systemSettings,
    ),
  ];

  /// Entity administration capabilities.
  static const List<AdminCapability> entity = [
    AdminCapability(
      key: 'entity_overview',
      label: 'Entity Overview',
      description: 'Status and governance of the active entity.',
      iconKey: 'dashboard',
      scope: AdminScope.entity,
      permissionKey: AdminPermissions.entityOverview,
    ),
    AdminCapability(
      key: 'entity_members',
      label: 'Members',
      description: 'Manage entity membership.',
      iconKey: 'people',
      scope: AdminScope.entity,
      permissionKey: AdminPermissions.entityMembers,
    ),
    AdminCapability(
      key: 'entity_roles',
      label: 'Roles & Permissions',
      description: 'Manage entity roles and permissions.',
      iconKey: 'verified',
      scope: AdminScope.entity,
      permissionKey: AdminPermissions.entityRoles,
    ),
    AdminCapability(
      key: 'entity_workspace_access',
      label: 'Workspace Access',
      description: 'Control which workspaces members can use.',
      iconKey: 'widgets',
      scope: AdminScope.entity,
      permissionKey: AdminPermissions.entityWorkspaceAccess,
    ),
    AdminCapability(
      key: 'entity_module_access',
      label: 'Module Access',
      description: 'Control which modules the entity can use.',
      iconKey: 'list_alt',
      scope: AdminScope.entity,
      permissionKey: AdminPermissions.entityModuleAccess,
    ),
    AdminCapability(
      key: 'entity_profile',
      label: 'Entity Profile',
      description: 'Manage the entity profile and identity.',
      iconKey: 'business',
      scope: AdminScope.entity,
      permissionKey: AdminPermissions.entityProfile,
    ),
    AdminCapability(
      key: 'entity_business_profiles',
      label: 'Business Profiles',
      description: 'Manage business profiles for the entity.',
      iconKey: 'store',
      scope: AdminScope.entity,
      permissionKey: AdminPermissions.entityBusinessProfiles,
    ),
    AdminCapability(
      key: 'entity_approvals',
      label: 'Approvals',
      description: 'Review entity approval requests.',
      iconKey: 'check',
      scope: AdminScope.entity,
      permissionKey: AdminPermissions.entityApprovals,
    ),
    AdminCapability(
      key: 'entity_audit_trail',
      label: 'Audit Trail',
      description: 'Review the entity audit trail.',
      iconKey: 'history',
      scope: AdminScope.entity,
      permissionKey: AdminPermissions.entityAuditTrail,
    ),
    AdminCapability(
      key: 'entity_settings',
      label: 'Entity Settings',
      description: 'Manage entity-wide configuration.',
      iconKey: 'settings',
      scope: AdminScope.entity,
      permissionKey: AdminPermissions.entitySettings,
    ),
  ];

  /// Every capability descriptor, platform first.
  static const List<AdminCapability> all = [
    ...platform,
    ...entity,
  ];
}
