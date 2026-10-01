/// ============================================================
/// LOGISTICS RPC GATEWAY
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/infrastructure/data_sources/
///     = Supabase access for the logistics module
///
/// ✅ Responsibilities:
///   - Single source of truth for the confirmed backend RPC
///     function names and parameter maps.
///   - Route every Logistics write through `schema('logistics').rpc(...)`.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - No direct UPDATE/INSERT against `logistics.tracking_sessions`
///     or `logistics.location_points`. The RPCs are the only write path.
///   - The Supabase call is injectable so contract tests can assert the
///     exact function name and parameters without a live backend.
///
/// ❌ Does NOT:
///   - Grant permissions (backend RLS/RPC authorization is authoritative)
///   - Contain UI or state
/// ============================================================
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Exact backend RPC names — confirmed contract, never invent alternatives.
abstract final class LogisticsRpcNames {
  static const String startTrackingSession = 'start_tracking_session';
  static const String pauseTrackingSession = 'pause_tracking_session';
  static const String resumeTrackingSession = 'resume_tracking_session';
  static const String completeTrackingSession = 'complete_tracking_session';
  static const String recordLocationPoint = 'record_location_point';
  static const String assignTransport = 'assign_transport';
}

/// Raw Supabase RPC invocation. Injectable for tests.
typedef LogisticsRpcCall = Future<dynamic> Function(
  String function, {
  Map<String, dynamic>? params,
});

/// Backend RPC contract used by the Logistics feature.
abstract class LogisticsRpcGateway {
  Future<String> startTrackingSession({required String assignmentId});

  Future<String> pauseTrackingSession({required String trackingSessionId});

  Future<String> resumeTrackingSession({required String trackingSessionId});

  Future<String> completeTrackingSession({required String trackingSessionId});

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

  Future<String> assignTransport({
    required String shipmentId,
    required String providerEntityId,
    String? driverProfileId,
    String? vehicleId,
    String? notes,
  });
}

/// Supabase-backed implementation of the confirmed RPC contract.
class SupabaseLogisticsRpcGateway implements LogisticsRpcGateway {
  final SupabaseClient? _client;
  final LogisticsRpcCall? _rpc;

  SupabaseLogisticsRpcGateway({SupabaseClient? client, LogisticsRpcCall? rpc})
      : _client = client,
        _rpc = rpc;

  Future<String> _call(
    String function, {
    required Map<String, dynamic> params,
  }) async {
    final dynamic response;
    final rpc = _rpc;
    if (rpc != null) {
      response = await rpc(function, params: params);
    } else {
      final client = _client ?? Supabase.instance.client;
      response = await client.schema('logistics').rpc(function, params: params);
    }
    return _extractId(response, function);
  }

  @override
  Future<String> startTrackingSession({required String assignmentId}) {
    return _call(
      LogisticsRpcNames.startTrackingSession,
      params: {'p_assignment_id': assignmentId},
    );
  }

  @override
  Future<String> pauseTrackingSession({required String trackingSessionId}) {
    return _call(
      LogisticsRpcNames.pauseTrackingSession,
      params: {'p_tracking_session_id': trackingSessionId},
    );
  }

  @override
  Future<String> resumeTrackingSession({required String trackingSessionId}) {
    return _call(
      LogisticsRpcNames.resumeTrackingSession,
      params: {'p_tracking_session_id': trackingSessionId},
    );
  }

  @override
  Future<String> completeTrackingSession({required String trackingSessionId}) {
    return _call(
      LogisticsRpcNames.completeTrackingSession,
      params: {'p_tracking_session_id': trackingSessionId},
    );
  }

  @override
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
  }) {
    final params = <String, dynamic>{
      'p_tracking_session_id': trackingSessionId,
      'p_idempotency_key': idempotencyKey,
      'p_captured_at': capturedAt.toUtc().toIso8601String(),
      'p_latitude': latitude,
      'p_longitude': longitude,
      if (accuracy != null) 'p_accuracy': accuracy,
      if (speed != null) 'p_speed': speed,
      if (heading != null) 'p_heading': heading,
      if (altitude != null) 'p_altitude': altitude,
    };
    return _call(LogisticsRpcNames.recordLocationPoint, params: params);
  }

  @override
  Future<String> assignTransport({
    required String shipmentId,
    required String providerEntityId,
    String? driverProfileId,
    String? vehicleId,
    String? notes,
  }) {
    final params = <String, dynamic>{
      'p_shipment_id': shipmentId,
      'p_provider_entity_id': providerEntityId,
      if (driverProfileId != null && driverProfileId.isNotEmpty)
        'p_driver_profile_id': driverProfileId,
      if (vehicleId != null && vehicleId.isNotEmpty) 'p_vehicle_id': vehicleId,
      if (notes != null && notes.trim().isNotEmpty) 'p_notes': notes.trim(),
    };
    return _call(LogisticsRpcNames.assignTransport, params: params);
  }

  /// PostgREST returns the `RETURNS uuid` value as a bare string, a
  /// single-element array or a wrapped object depending on the function
  /// signature — normalize all three.
  static String _extractId(dynamic response, String function) {
    dynamic value = response;
    if (value is List) value = value.isEmpty ? null : value.first;
    if (value is Map) {
      value = value['id'] ??
          value[function] ??
          (value.isEmpty ? null : value.values.first);
    }
    final id = value?.toString();
    if (id == null || id.isEmpty || id == 'null') {
      throw LogisticsRpcContractException(
        'The backend did not return an id for "$function".',
      );
    }
    return id;
  }
}

/// Raised when a backend RPC response cannot be interpreted.
class LogisticsRpcContractException implements Exception {
  final String message;
  const LogisticsRpcContractException(this.message);

  @override
  String toString() => message;
}
