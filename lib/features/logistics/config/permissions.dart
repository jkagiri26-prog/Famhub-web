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

  // ── Shipment administration ────────────────────────────────
  static const String viewShipments = 'logistics.view_shipments';
  static const String createShipments = 'logistics.create_shipments';
  static const String manageShipments = 'logistics.manage_shipments';
  static const String confirmDelivery = 'logistics.confirm_delivery';

  // ── Transport administration ───────────────────────────────
  static const String assignTransport = 'logistics.assign_transport';
  static const String manageVehicles = 'logistics.manage_vehicles';
  static const String manageDrivers = 'logistics.manage_drivers';

  // ── Tracking ───────────────────────────────────────────────
  static const String updateTracking = 'logistics.update_tracking';
  static const String viewLiveTracking = 'logistics.view_live_tracking';
  static const String recordLocation = 'logistics.record_location';

  /// Full registry — used for validation / seeding / policy sync.
  static const List<String> all = [
    viewShipments,
    createShipments,
    manageShipments,
    confirmDelivery,
    assignTransport,
    manageVehicles,
    manageDrivers,
    updateTracking,
    viewLiveTracking,
    recordLocation,
  ];
}
