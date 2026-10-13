/// ============================================================
/// FINANCING — PERMISSION KEYS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/financing/config/ = feature configuration
///
/// ✅ Responsibilities:
///   - Declare the permission keys used by the Financing feature.
///
/// ❌ Does NOT:
///   - Grant any permission. These are contract identifiers only.
///   - Evaluate access. Evaluation is owned by the backend
///     authorization function `core.has_permission(p_permission)`
///     reached through `AccessPolicyRepository.hasPermission`.
///
/// Backend seed (migration 20261012000001):
///   finance.manage_providers, finance.verify_providers,
///   finance.manage_products, finance.review_products,
///   finance.publish_products
///
/// ⚠️ GRANT MODEL:
///   Resolution requires BOTH a `core.role_permissions` row AND a matching
///   `core.entity_role_scopes` row for the caller's ACTIVE context
///   (scope_type='module', entity_id = active entity, module = permission's
///   module). Role membership alone is not enough. Granting is therefore
///   always a data decision, never a code decision.
///
///   AT MIGRATION TIME (20261012000001) the migration registered these five
///   codes in `core.permissions` and deliberately seeded **no**
///   `core.role_permissions` rows, **no** `core.entity_role_scopes` rows and
///   no role assignment. The operator recipe for adding them is documented at
///   the top of that migration.
///
///   CURRENT PRODUCTION STATE (verified 2026-10-13): that recipe has since
///   been applied. All five codes carry active grants on the Admin role
///   (60773165-412a-4d1b-98da-5c9f2e7fe307), together with a matching
///   scope_type='module' / module='finance' row in `core.entity_role_scopes`
///   for profile 01a03733-ce44-7f82-ba8d-d12d97025346 acting in the FAMHUB
///   Platform Administration entity (01a091e6-f283-70b5-9393-813acf541c09).
///   The Finance module is enabled and not in maintenance mode.
///
///   SCOPE LIMIT: those grants resolve only for that Admin role inside that
///   entity. The same profile acting as Owner of a different workspace
///   legitimately evaluates to false — that is correct scoping, not a defect,
///   and these keys must not be read as implying authorization elsewhere.
///
///   ERROR MODEL: `core.has_permission` returns a boolean and never raises.
///   The SQLSTATE 42501 a client sees on a write comes from
///   `financing._require_permission`, which raises 'Authentication required'
///   when `auth.uid()` is NULL, and 'Finance permission denied: <code>' when
///   the profile cannot be resolved or `core.has_permission` is false.
///
///   Precedent in this repo: `knowledge.*` is seeded into role_permissions;
///   `logistics.*` is registered with none.
///
///   Also note: API roles need `USAGE` on schema `financing` (granted to
///   authenticated + service_role by the migration, deliberately **not** to
///   anon) or PostgREST cannot address these objects at all.
/// ============================================================
library;

class FinancingPermissions {
  const FinancingPermissions._();

  // ── Provider catalog ───────────────────────────────────────
  static const String manageProviders = 'finance.manage_providers';
  static const String verifyProviders = 'finance.verify_providers';

  // ── Product catalog ────────────────────────────────────────
  static const String manageProducts = 'finance.manage_products';
  static const String reviewProducts = 'finance.review_products';
  static const String publishProducts = 'finance.publish_products';

  /// Full registry — used for validation / seeding / policy sync.
  static const List<String> all = [
    manageProviders,
    verifyProviders,
    manageProducts,
    reviewProducts,
    publishProducts,
  ];
}
