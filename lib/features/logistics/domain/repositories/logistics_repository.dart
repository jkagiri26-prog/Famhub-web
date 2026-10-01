/// ============================================================
/// LOGISTICS REPOSITORY (DOMAIN CONTRACT)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/domain/repositories/ = abstract contract
///
/// ✅ Responsibilities:
///   - Declare the bounded reads the Logistics feature needs.
///   - Declare the backend RPC-backed actions the Logistics feature
///     exposes (transport assignment + tracking lifecycle + GPS).
///
/// ❌ Does NOT:
///   - Reference Supabase or any infrastructure type
///   - Contain UI or state
///
/// All reads are entity-scoped by the backend RLS. The optional
/// `entityId` argument only narrows reads further using the active
/// entity already derived by the FAMHUB context mechanism — it is
/// never an ownership grant.
///
/// Every write is delegated to a backend RPC. Direct writes against
/// `logistics.*` tables (in particular `tracking_sessions.status` and
/// `location_points`) are intentionally absent from this contract.
/// ============================================================
library;

import '../models/logistics_dashboard_models.dart';
import '../models/logistics_detail_models.dart';

abstract class LogisticsRepository {
  /// One bounded, entity-aware payload for the Logistics dashboard.
  ///
  /// Implementations must cap every list and select only the columns
  /// the dashboard renders (low-data requirement).
  Future<LogisticsDashboardSnapshot> fetchDashboard({String? entityId});

  /// Bounded shipment list for the shipments page.
  Future<List<LogisticsShipment>> fetchShipments({
    String? entityId,
    int limit,
  });

  /// Bounded, fully assembled shipment detail payload.
  /// Returns null when the backend does not expose the shipment.
  Future<LogisticsShipmentDetail?> fetchShipmentDetail(
    String shipmentId, {
    String? entityId,
  });

  /// Best-effort candidate lists for transport administration.
  Future<LogisticsTransportOptions> fetchTransportOptions({String? entityId});

  /// Most recent tracking session attached to an assignment (any status).
  Future<LogisticsTrackingSession?> fetchLatestTrackingSession(
    String assignmentId,
  );

  /// Bounded session list for the live-tracking page.
  Future<List<LogisticsTrackingSession>> fetchTrackingSessions({
    String? entityId,
    int limit,
  });

  /// Bounded location history for one tracking session.
  Future<LogisticsTrackingSessionDetail?> fetchTrackingSessionDetail(
    String trackingSessionId, {
    int pointLimit,
  });

  // ── Backend RPC actions ─────────────────────────────────────

  /// `logistics.start_tracking_session(p_assignment_id) -> uuid`
  Future<String> startTrackingSession({required String assignmentId});

  /// `logistics.pause_tracking_session(p_tracking_session_id) -> uuid`
  Future<String> pauseTrackingSession({required String trackingSessionId});

  /// `logistics.resume_tracking_session(p_tracking_session_id) -> uuid`
  Future<String> resumeTrackingSession({required String trackingSessionId});

  /// `logistics.complete_tracking_session(p_tracking_session_id) -> uuid`
  Future<String> completeTrackingSession({required String trackingSessionId});

  /// `logistics.record_location_point(...) -> uuid`
  ///
  /// The idempotency key is generated once per physical point and reused
  /// on every retry so a retry can never create a duplicate point.
  Future<String> recordLocationPoint({
    required String trackingSessionId,
    required String idempotencyKey,
    required DateTime capturedAt,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
    double? altitude,
  });

  /// `logistics.assign_transport(p_shipment_id, p_provider_entity_id,
  ///   p_driver_profile_id, p_vehicle_id, p_notes) -> uuid`
  Future<String> assignTransport({
    required String shipmentId,
    required String providerEntityId,
    String? driverProfileId,
    String? vehicleId,
    String? notes,
  });
}
