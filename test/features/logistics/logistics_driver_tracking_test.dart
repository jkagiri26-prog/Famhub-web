import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/logistics/application/providers/logistics_driver_tracking_provider.dart';
import 'package:famhub_app/features/logistics/application/services/device_location_source.dart';
import 'package:famhub_app/features/logistics/config/permissions.dart';
import 'package:famhub_app/features/logistics/domain/models/logistics_dashboard_models.dart';
import 'package:famhub_app/features/logistics/presentation/widgets/logistics_driver_tracking_controls_widget.dart';

import 'logistics_test_harness.dart';

const DriverTrackingTarget _target = DriverTrackingTarget(
  assignmentId: 'assign-1',
  shipmentId: '018f0000-0000-7000-8000-000000000001',
);

LogisticsTrackingSession _session(String status, {String id = 'sess-1'}) {
  return LogisticsTrackingSession.fromMap(<String, dynamic>{
    'id': id,
    'shipment_id': '018f0000-0000-7000-8000-000000000001',
    'assignment_id': 'assign-1',
    'status': status,
    'started_at': '2026-03-12T09:30:00+00:00',
  });
}

ProviderContainer _container({
  required FakeLogisticsRepository repository,
  FakeDeviceLocationSource? device,
  Set<String>? allowedPermissions,
}) {
  final container = ProviderContainer(
    overrides: defaultOverrides(
      repository: repository,
      deviceLocationSource: device ?? FakeDeviceLocationSource(),
      allowedPermissions: allowedPermissions,
    ),
  );
  addTearDown(container.dispose);
  return container;
}

Future<DriverTrackingState> _hydrate(ProviderContainer container) async {
  final provider = driverTrackingControllerProvider(_target);
  final subscription = container.listen(
    provider,
    (previous, next) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
  await settle();
  return container.read(provider);
}

Future<void> _act(ProviderContainer container) async {
  await settle(40);
}

void main() {
  group('tracking session lifecycle', () {
    test(
        'hydration loads the latest session without touching device location',
        () async {
      final repository = FakeLogisticsRepository()
        ..latestTrackingSession = _session('active');
      final device = FakeDeviceLocationSource();
      final container = _container(repository: repository, device: device);

      final state = await _hydrate(container);

      expect(state.isLoading, isFalse);
      expect(state.sessionId, 'sess-1');
      expect(state.sessionStatus, LogisticsTrackingStatus.active);
      expect(state.isRecording, isFalse);
      expect(device.permissionRequests, 0);
      expect(device.watchRequests, 0);
      expect(repository.startCount, 0);
    });

    test(
        'Start invokes start_tracking_session(p_assignment_id) and only then '
        'requests device location', () async {
      final repository = FakeLogisticsRepository();
      final device = FakeDeviceLocationSource();
      final container = _container(repository: repository, device: device);

      final state = await _hydrate(container);
      expect(device.permissionRequests, 0);

      await container
          .read(driverTrackingControllerProvider(_target).notifier)
          .start();
      await _act(container);

      expect(repository.startCount, 1);
      expect(repository.startAssignmentIds, ['assign-1']);

      final after =
          container.read(driverTrackingControllerProvider(_target));
      expect(after.sessionId, 'session-1');
      expect(after.sessionStatus, LogisticsTrackingStatus.active);
      expect(after.isRecording, isTrue);
      expect(device.permissionRequests, 1);
      expect(device.watchRequests, 1);
      expect(state.isLoading, isFalse);
    });

    test('pause, resume and complete call the confirmed RPCs in order',
        () async {
      final repository = FakeLogisticsRepository();
      final device = FakeDeviceLocationSource();
      final container = _container(repository: repository, device: device);
      final notifier =
          container.read(driverTrackingControllerProvider(_target).notifier);

      await _hydrate(container);
      await notifier.start();
      await _act(container);
      expect(device.watchRequests, 1);

      await notifier.pause();
      await _act(container);
      expect(repository.pauseSessionIds, ['session-1']);
      expect(
        container.read(driverTrackingControllerProvider(_target)).sessionStatus,
        LogisticsTrackingStatus.paused,
      );
      expect(
        container.read(driverTrackingControllerProvider(_target)).isRecording,
        isFalse,
      );

      await notifier.resume();
      await _act(container);
      expect(repository.resumeSessionIds, ['session-1']);
      expect(
        container.read(driverTrackingControllerProvider(_target)).sessionStatus,
        LogisticsTrackingStatus.active,
      );
      expect(device.watchRequests, 2);

      await notifier.complete();
      await _act(container);
      expect(repository.completeSessionIds, ['session-1']);
      final finalState =
          container.read(driverTrackingControllerProvider(_target));
      expect(finalState.sessionStatus, LogisticsTrackingStatus.completed);
      expect(finalState.isRecording, isFalse);
      expect(finalState.isTerminalSession, isTrue);
      expect(finalState.canStartSession, isFalse);
      expect(finalState.canPauseSession, isFalse);
      expect(finalState.canResumeSession, isFalse);
      expect(finalState.canCompleteSession, isFalse);
    });

    test('a backend rejection surfaces safe copy and changes nothing',
        () async {
      final repository = FakeLogisticsRepository()
        ..actionError =
            permissionDeniedRpc('logistics.start_tracking_session');
      final device = FakeDeviceLocationSource();
      final container = _container(repository: repository, device: device);

      await _hydrate(container);
      await container
          .read(driverTrackingControllerProvider(_target).notifier)
          .start();
      await _act(container);

      final state = container.read(driverTrackingControllerProvider(_target));
      expect(repository.startCount, 0);
      expect(state.sessionStatus, isNull);
      expect(state.isBusy, isFalse);
      expect(
        state.lastError,
        "You don't have permission to update tracking for this shipment.",
      );
      expect(state.lastError!.contains('start_tracking_session'), isFalse);
      expect(state.lastError!.contains('42501'), isFalse);
      expect(device.permissionRequests, 0);
    });
  });

  group('location points', () {
    test(
        'record_location_point carries the captured sample verbatim',
        () async {
      final repository = FakeLogisticsRepository();
      final device = FakeDeviceLocationSource();
      final container = _container(repository: repository, device: device);

      await _hydrate(container);
      await container
          .read(driverTrackingControllerProvider(_target).notifier)
          .start();
      await _act(container);

      device.emit(sampleFixture());
      await _act(container);

      expect(repository.recordLocationCount, 1);
      final call = repository.recordLocationCalls.single;
      expect(call['trackingSessionId'], 'session-1');
      expect(call['capturedAt'], DateTime.parse('2026-03-12T10:00:00Z'));
      expect(call['latitude'], -1.2921);
      expect(call['longitude'], 36.8219);
      expect(call['accuracy'], 5);
      expect(call['speed'], 8.5);
      expect(call['heading'], 90);
      expect(call['altitude'], 1700);
      expect(
        call['idempotencyKey'],
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        )),
      );

      final state = container.read(driverTrackingControllerProvider(_target));
      expect(state.sentCount, 1);
      expect(state.queuedCount, 0);
      expect(state.failedCount, 0);
      expect(state.lastError, isNull);
    });

    test(
        'a failed point is queued and retried with the SAME idempotency key',
        () async {
      final repository = FakeLogisticsRepository()..locationFailures = 1;
      final device = FakeDeviceLocationSource();
      final container = _container(repository: repository, device: device);

      await _hydrate(container);
      final notifier =
          container.read(driverTrackingControllerProvider(_target).notifier);
      await notifier.start();
      await _act(container);

      device.emit(sampleFixture());
      await _act(container);

      expect(repository.recordLocationCount, 1);
      var state = container.read(driverTrackingControllerProvider(_target));
      expect(state.failedCount, 1);
      expect(state.queuedCount, 1);
      expect(state.sentCount, 0);
      expect(state.lastError, isNotNull);

      await notifier.retryQueued();
      await _act(container);

      expect(repository.recordLocationCount, 2);
      final first = repository.recordLocationCalls.first;
      final second = repository.recordLocationCalls.last;
      expect(second['idempotencyKey'], first['idempotencyKey']);

      state = container.read(driverTrackingControllerProvider(_target));
      expect(state.sentCount, 1);
      expect(state.queuedCount, 0);
      expect(state.lastError, isNull);
    });

    test('no points are captured while the session is paused',
        () async {
      final repository = FakeLogisticsRepository()
        ..latestTrackingSession = _session('paused');
      final device = FakeDeviceLocationSource();
      final container = _container(repository: repository, device: device);

      await _hydrate(container);
      final notifier =
          container.read(driverTrackingControllerProvider(_target).notifier);

      await notifier.startRecording();
      await _act(container);

      expect(device.permissionRequests, 0);
      expect(device.watchRequests, 0);

      device.emit(sampleFixture());
      await _act(container);

      expect(repository.recordLocationCount, 0);
    });

    test('a denied device permission stops recording with safe copy',
        () async {
      final repository = FakeLogisticsRepository();
      final device = FakeDeviceLocationSource()
        ..permissionState = DeviceLocationState.permanentlyDenied;
      final container = _container(repository: repository, device: device);

      await _hydrate(container);
      await container
          .read(driverTrackingControllerProvider(_target).notifier)
          .start();
      await _act(container);

      final state = container.read(driverTrackingControllerProvider(_target));
      expect(state.isRecording, isFalse);
      expect(state.deviceState, DeviceLocationState.permanentlyDenied);
      expect(state.lastError, contains('Location access is blocked'));
      expect(device.watchRequests, 0);
      expect(repository.recordLocationCount, 0);
    });
  });

  group('permission gating', () {
    testWidgets('tracking controls stay locked without update_tracking',
        (tester) async {
      final repository = FakeLogisticsRepository();
      await pumpTestApp(
        tester,
        const LogisticsDriverTrackingControlsWidget(target: _target),
        overrides: defaultOverrides(
          repository: repository,
          deviceLocationSource: FakeDeviceLocationSource(),
          allowedPermissions: const {LogisticsPermissions.viewShipments},
        ),
      );

      expect(find.text('Tracking locked'), findsOneWidget);
      expect(find.text('Start tracking'), findsNothing);
      expect(repository.startCount, 0);
    });

    testWidgets('the recording toggle is unavailable without record_location',
        (tester) async {
      final repository = FakeLogisticsRepository()
        ..latestTrackingSession = _session('active');

      await pumpTestApp(
        tester,
        const LogisticsDriverTrackingControlsWidget(target: _target),
        overrides: defaultOverrides(
          repository: repository,
          deviceLocationSource: FakeDeviceLocationSource(),
          allowedPermissions: const {
            LogisticsPermissions.viewShipments,
            LogisticsPermissions.updateTracking,
          },
        ),
      );

      expect(find.text('Location recording is not enabled for your role.'),
          findsOneWidget);
      expect(find.text('Start recording'), findsNothing);
    });
  });

  group('controls', () {
    testWidgets('every lifecycle control is disabled while an RPC is in flight',
        (tester) async {
      final repository = FakeLogisticsRepository()
        ..startGate = Completer<void>();
      final device = FakeDeviceLocationSource();

      await pumpTestApp(
        tester,
        const LogisticsDriverTrackingControlsWidget(target: _target),
        overrides: defaultOverrides(
          repository: repository,
          deviceLocationSource: device,
        ),
      );

      final startButton = find.widgetWithText(ElevatedButton, 'Start tracking');
      expect(startButton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(startButton).onPressed, isNotNull);

      await tester.tap(startButton);
      await tester.pump();

      expect(find.text('Working...'), findsOneWidget);
      final busy = find.widgetWithText(ElevatedButton, 'Working...');
      expect(tester.widget<ElevatedButton>(busy).onPressed, isNull);
      expect(device.permissionRequests, 0);

      repository.startGate!.complete();
      await tester.pumpAndSettle();

      expect(repository.startCount, 1);
      // Pause is the secondary variant (OutlinedButton); Complete is primary.
      expect(find.widgetWithText(OutlinedButton, 'Pause'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Complete'), findsOneWidget);
      expect(find.text('Start tracking'), findsNothing);
    });

    testWidgets('a terminal session exposes no lifecycle controls',
        (tester) async {
      final repository = FakeLogisticsRepository()
        ..latestTrackingSession = _session('completed');

      await pumpTestApp(
        tester,
        const LogisticsDriverTrackingControlsWidget(target: _target),
        overrides: defaultOverrides(
          repository: repository,
          deviceLocationSource: FakeDeviceLocationSource(),
        ),
      );

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Start tracking'), findsNothing);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Complete'), findsNothing);
      expect(find.text('Start recording'), findsNothing);
      expect(
        find.textContaining(
          'This tracking session has ended. No further tracking '
          'actions are available.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a cancelled session exposes no lifecycle controls',
        (tester) async {
      final repository = FakeLogisticsRepository()
        ..latestTrackingSession = _session('cancelled', id: 'sess-2');

      await pumpTestApp(
        tester,
        const LogisticsDriverTrackingControlsWidget(target: _target),
        overrides: defaultOverrides(
          repository: repository,
          deviceLocationSource: FakeDeviceLocationSource(),
        ),
      );

      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Start tracking'), findsNothing);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Complete'), findsNothing);
    });

    testWidgets('a paused session offers Resume and Complete only',
        (tester) async {
      final repository = FakeLogisticsRepository()
        ..latestTrackingSession = _session('paused');

      await pumpTestApp(
        tester,
        const LogisticsDriverTrackingControlsWidget(target: _target),
        overrides: defaultOverrides(
          repository: repository,
          deviceLocationSource: FakeDeviceLocationSource(),
        ),
      );

      expect(find.text('Paused'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Resume'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Complete'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      expect(find.text('Start tracking'), findsNothing);
      expect(find.text('Start recording'), findsNothing);
    });
  });
}
