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
/// ⚠️ GRANT MODEL / OPEN BLOCKER (see migration header):
///   The migration registers these five codes in `core.permissions` only.
///   It deliberately creates **no** `core.role_permissions` rows and **no**
///   `core.entity_role_scopes` rows, and assigns no role.
///   `core.has_permission` requires BOTH a role_permissions row AND a matching
///   entity_role_scopes row (scope_type='module', module=the permission's
///   module), so until an operator seeds both, every code below fails closed
///   with 42501 for every role — including Admin.
///   Operator recipe is documented at the top of the migration.
///
///   Precedent in this repo: `knowledge.*` is seeded into role_permissions;
///   `logistics.*` is registered with none. Zero `scope_type='module'` rows
///   exist in production today, which is why no code change can make these
///   grants live — it is a data decision, not a code decision.
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
