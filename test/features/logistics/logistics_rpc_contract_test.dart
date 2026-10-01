import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/features/logistics/infrastructure/data_sources/logistics_rpc_gateway.dart';
import 'package:famhub_app/features/logistics/infrastructure/services/logistics_action_error_mapper.dart';

import 'logistics_test_harness.dart';

class _RpcCall {
  final String name;
  final Map<String, dynamic>? params;

  const _RpcCall(this.name, this.params);
}

class _RecordingRpc {
  final List<_RpcCall> calls = <_RpcCall>[];
  Object? error;
  dynamic response = 'session-1';

  Future<dynamic> call(
    String function, {
    Map<String, dynamic>? params,
  }) async {
    calls.add(_RpcCall(function, params));
    final failure = error;
    if (failure != null) throw failure;
    return response;
  }
}

SupabaseLogisticsRpcGateway _gateway(_RecordingRpc recorder) {
  return SupabaseLogisticsRpcGateway(rpc: recorder.call);
}

void main() {
  group('Confirmed Logistics RPC contract', () {
    test('function names match the backend contract exactly', () {
      expect(LogisticsRpcNames.startTrackingSession, 'start_tracking_session');
      expect(LogisticsRpcNames.pauseTrackingSession, 'pause_tracking_session');
      expect(LogisticsRpcNames.resumeTrackingSession, 'resume_tracking_session');
      expect(
        LogisticsRpcNames.completeTrackingSession,
        'complete_tracking_session',
      );
      expect(LogisticsRpcNames.recordLocationPoint, 'record_location_point');
      expect(LogisticsRpcNames.assignTransport, 'assign_transport');
    });

    test('start tracking invokes start_tracking_session(p_assignment_id)',
        () async {
      final recorder = _RecordingRpc()..response = 'sess-9';

      final id = await _gateway(recorder).startTrackingSession(
        assignmentId: 'assignment-9',
      );

      expect(id, 'sess-9');
      expect(recorder.calls, hasLength(1));
      expect(recorder.calls.single.name, 'start_tracking_session');
      expect(recorder.calls.single.params, {'p_assignment_id': 'assignment-9'});
    });

    test('pause tracking invokes pause_tracking_session(p_tracking_session_id)',
        () async {
      final recorder = _RecordingRpc()..response = 'sess-1';

      await _gateway(recorder).pauseTrackingSession(trackingSessionId: 'sess-1');

      expect(recorder.calls.single.name, 'pause_tracking_session');
      expect(
        recorder.calls.single.params,
        {'p_tracking_session_id': 'sess-1'},
      );
    });

    test('resume tracking invokes resume_tracking_session(p_tracking_session_id)',
        () async {
      final recorder = _RecordingRpc()..response = 'sess-1';

      await _gateway(recorder).resumeTrackingSession(trackingSessionId: 'sess-1');

      expect(recorder.calls.single.name, 'resume_tracking_session');
      expect(
        recorder.calls.single.params,
        {'p_tracking_session_id': 'sess-1'},
      );
    });

    test(
        'complete tracking invokes '
        'complete_tracking_session(p_tracking_session_id)', () async {
      final recorder = _RecordingRpc()..response = 'sess-1';

      await _gateway(recorder)
          .completeTrackingSession(trackingSessionId: 'sess-1');

      expect(recorder.calls.single.name, 'complete_tracking_session');
      expect(
        recorder.calls.single.params,
        {'p_tracking_session_id': 'sess-1'},
      );
    });

    test('record location point invokes record_location_point with exact params',
        () async {
      final recorder = _RecordingRpc()..response = 'point-1';

      final id = await _gateway(recorder).recordLocationPoint(
        trackingSessionId: 'sess-1',
        idempotencyKey: '8b2a4d7e-1f3c-4a5b-9c8d-0e1f2a3b4c5d',
        capturedAt: DateTime.utc(2026, 3, 12, 10),
        latitude: -1.2921,
        longitude: 36.8219,
        accuracy: 5,
        speed: 8.5,
        heading: 90,
        altitude: 1700,
      );

      expect(id, 'point-1');
      expect(recorder.calls.single.name, 'record_location_point');
      expect(recorder.calls.single.params, <String, dynamic>{
        'p_tracking_session_id': 'sess-1',
        'p_idempotency_key': '8b2a4d7e-1f3c-4a5b-9c8d-0e1f2a3b4c5d',
        'p_captured_at': '2026-03-12T10:00:00.000Z',
        'p_latitude': -1.2921,
        'p_longitude': 36.8219,
        'p_accuracy': 5.0,
        'p_speed': 8.5,
        'p_heading': 90.0,
        'p_altitude': 1700.0,
      });
    });

    test('record location point omits optional readings and normalises time',
        () async {
      final recorder = _RecordingRpc()..response = 'point-2';

      await _gateway(recorder).recordLocationPoint(
        trackingSessionId: 'sess-1',
        idempotencyKey: '8b2a4d7e-1f3c-4a5b-9c8d-0e1f2a3b4c5d',
        capturedAt: DateTime.parse('2026-03-12T13:00:00+03:00'),
        latitude: 0,
        longitude: 0,
      );

      expect(recorder.calls.single.params, <String, dynamic>{
        'p_tracking_session_id': 'sess-1',
        'p_idempotency_key': '8b2a4d7e-1f3c-4a5b-9c8d-0e1f2a3b4c5d',
        'p_captured_at': '2026-03-12T10:00:00.000Z',
        'p_latitude': 0,
        'p_longitude': 0,
      });
    });

    test('assign transport invokes assign_transport with required params only',
        () async {
      final recorder = _RecordingRpc()..response = 'assignment-1';

      final id = await _gateway(recorder).assignTransport(
        shipmentId: 'ship-1',
        providerEntityId: 'prov-1',
      );

      expect(id, 'assignment-1');
      expect(recorder.calls.single.name, 'assign_transport');
      expect(recorder.calls.single.params, <String, dynamic>{
        'p_shipment_id': 'ship-1',
        'p_provider_entity_id': 'prov-1',
      });
    });

    test('assign transport forwards every optional administration input',
        () async {
      final recorder = _RecordingRpc()..response = 'assignment-2';

      await _gateway(recorder).assignTransport(
        shipmentId: 'ship-2',
        providerEntityId: 'prov-2',
        driverProfileId: 'driver-2',
        vehicleId: 'veh-2',
        notes: '  Leave at gate  ',
      );

      expect(recorder.calls.single.params, <String, dynamic>{
        'p_shipment_id': 'ship-2',
        'p_provider_entity_id': 'prov-2',
        'p_driver_profile_id': 'driver-2',
        'p_vehicle_id': 'veh-2',
        'p_notes': 'Leave at gate',
      });
    });

    test('assign transport ignores blank optional values', () async {
      final recorder = _RecordingRpc()..response = 'assignment-3';

      await _gateway(recorder).assignTransport(
        shipmentId: 'ship-3',
        providerEntityId: 'prov-3',
        driverProfileId: '',
        vehicleId: '',
        notes: '   ',
      );

      expect(recorder.calls.single.params, <String, dynamic>{
        'p_shipment_id': 'ship-3',
        'p_provider_entity_id': 'prov-3',
      });
    });
  });

  group('RPC response normalisation', () {
    test('accepts a bare uuid string', () async {
      final recorder = _RecordingRpc()..response = 'session-7';
      expect(
        await _gateway(recorder).startTrackingSession(assignmentId: 'a'),
        'session-7',
      );
    });

    test('accepts a single element array', () async {
      final recorder = _RecordingRpc()..response = <dynamic>['session-8'];
      expect(
        await _gateway(recorder).startTrackingSession(assignmentId: 'a'),
        'session-8',
      );
    });

    test('accepts an object wrapper', () async {
      final recorder = _RecordingRpc()
        ..response = <String, dynamic>{'id': 'session-10'};
      expect(
        await _gateway(recorder).startTrackingSession(assignmentId: 'a'),
        'session-10',
      );
    });

    test('rejects a response without an id instead of guessing', () async {
      final recorder = _RecordingRpc()..response = null;
      expect(
        () => _gateway(recorder).startTrackingSession(assignmentId: 'a'),
        throwsA(isA<LogisticsRpcContractException>()),
      );
    });
  });

  group('Action error mapping', () {
    test('permission denial is surfaced without leaking the RPC name', () {
      final message = describeTrackingActionError(
        permissionDeniedRpc('logistics.start_tracking_session'),
      );

      expect(
        message,
        "You don't have permission to update tracking for this shipment.",
      );
      expect(message.contains('start_tracking_session'), isFalse);
      expect(message.contains('sql'), isFalse);
      expect(message.contains('42501'), isFalse);
    });

    test('assignment permission denial maps to the assignment copy', () {
      final message = describeAssignTransportError(
        permissionDeniedRpc('logistics.assign_transport'),
      );
      expect(
        message,
        "You don't have permission to assign transport for this shipment.",
      );
      expect(message.contains('assign_transport'), isFalse);
    });

    test('network failure maps to a connection message', () {
      const error = PostgrestException(
        message: 'Failed host lookup: api.example.com',
      );
      expect(
        describeLocationPointError(error),
        'No connection. Check your network and try again.',
      );
    });

    test('an unknown failure maps to a generic safe message', () {
      final message = describeTrackingActionError(Exception('boom 0xdead'));
      expect(message, "We couldn't update tracking. Please try again.");
      expect(message.contains('0xdead'), isFalse);
    });

    test('a terminated session maps to the ended-session copy', () {
      final message = describeTrackingActionError(
        const PostgrestException(
          message: 'tracking session is already completed',
          code: 'P0001',
        ),
      );
      expect(message, 'This tracking session has already ended.');
    });
  });
}
