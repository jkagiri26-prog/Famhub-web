/// ============================================================
/// LOGISTICS — PERMISSION KEYS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/config/ = feature configuration
///
/// ✅ Responsibilities:
///   - Declare the permission keys used by the Logistics feature.
///
/// ❌ Does NOT:
///   - Grant any permission. These are contract identifiers only.
///   - Evaluate access. Evaluation is owned by the backend
///     authorization function `core.has_permission(p_permission)`
///     reached through `AccessPolicyRepository.hasPermission`.
/// ============================================================
library;

class LogisticsPermissions {
  const LogisticsPermissions._();

  // ── Existing logistics permissions ─────────────────────────
  static const String view = 'logistics.view';
  static const String book = 'logistics.book';
  static const String track = 'logistics.track';

  // ── Existing GPS permissions (backend Phase 1B) ────────────
  static const String viewLiveTracking = 'logistics.view_live_tracking';
  static const String recordLocation = 'logistics.record_location';

  /// Full registry — used for validation / seeding / policy sync.
  static const List<String> all = [
    view,
    book,
    track,
    viewLiveTracking,
    recordLocation,
  ];
}
