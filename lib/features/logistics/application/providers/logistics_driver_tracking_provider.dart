/// ============================================================
/// DRIVER TRACKING CONTROLLER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Drive the tracking session lifecycle through the confirmed
///     backend RPCs (start / pause / resume / complete).
///   - Capture device location ONLY while a session is `active` and the
///     device permission was granted from an explicit user action.
///   - Submit each point through `logistics.record_location_point` with
///     a per-point idempotency key that is reused verbatim on retry.
///   - Keep a small bounded buffer of undelivered points and retry them
///     only on explicit user action or when connectivity returns.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Never writes `logistics.tracking_sessions.status` directly.
///   - Never inserts into `logistics.location_points` directly.
///   - Never starts GPS on page/dashboard load.
///   - Backend RLS / RPC authorization stays authoritative; failures are
///     surfaced as safe, user-friendly copy.
///
/// ❌ Does NOT:
///   - Run a background tracking service
///   - Poll the backend
///   - Retry failed submissions in a tight loop
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/providers/connectivity_provider.dart';
import '../../domain/models/logistics_dashboard_models.dart';
import '../../domain/repositories/logistics_repository.dart';
import '../../infrastructure/services/logistics_action_error_mapper.dart';
import '../services/device_location_source.dart';
import '../services/logistics_location_point_queue.dart';
import 'logistics_dashboard_provider.dart';
import 'logistics_shipment_provider.dart';
import 'logistics_tracking_provider.dart';

/// Identity of the assignment a tracking controller belongs to.
///
/// Used as a Riverpod family argument, so equality matters.
class DriverTrackingTarget {
  final String assignmentId;
  final String? shipmentId;

  const DriverTrackingTarget({required this.assignmentId, this.shipmentId});

  @override
  bool operator ==(Object other) =>
      other is DriverTrackingTarget &&
      other.assignmentId == assignmentId &&
      other.shipmentId == shipmentId;

  @override
  int get hashCode => Object.hash(assignmentId, shipmentId);

  @override
  String toString() =>
      'DriverTrackingTarget(assignmentId: $assignmentId, '
      'shipmentId: $shipmentId)';
}

/// UI-facing state of the driver tracking experience.
class DriverTrackingState {
  final String assignmentId;
  final String? sessionId;

  /// `active` / `paused` / `completed` / `cancelled`, or null when no
  /// session exists for this assignment yet.
  final String? sessionStatus;

  final bool isLoading;
  final bool isBusy;

  /// Outcome of the device permission request. `unknown` until the user
  /// explicitly starts or resumes recording.
  final DeviceLocationState deviceState;

  final bool isRecording;
  final int sentCount;
  final int queuedCount;
  final int failedCount;
  final DateTime? lastSentAt;
  final String? lastError;

  const DriverTrackingState({
    required this.assignmentId,
    this.sessionId,
    this.sessionStatus,
    this.isLoading = false,
    this.isBusy = false,
    this.deviceState = DeviceLocationState.unknown,
    this.isRecording = false,
    this.sentCount = 0,
    this.queuedCount = 0,
    this.failedCount = 0,
    this.lastSentAt,
    this.lastError,
  });

  factory DriverTrackingState.initial(String assignmentId) =>
      DriverTrackingState(assignmentId: assignmentId, isLoading: true);

  DriverTrackingState copyWith({
    String? sessionId,
    String? sessionStatus,
    bool? isLoading,
    bool? isBusy,
    DeviceLocationState? deviceState,
    bool? isRecording,
    int? sentCount,
    int? queuedCount,
    int? failedCount,
    DateTime? lastSentAt,
    String? lastError,
    bool clearSession = false,
    bool clearError = false,
    bool clearLastSentAt = false,
  }) {
    return DriverTrackingState(
      assignmentId: assignmentId,
      sessionId: clearSession ? null : sessionId ?? this.sessionId,
      sessionStatus:
          clearSession ? null : sessionStatus ?? this.sessionStatus,
      isLoading: isLoading ?? this.isLoading,
      isBusy: isBusy ?? this.isBusy,
      deviceState: deviceState ?? this.deviceState,
      isRecording: isRecording ?? this.isRecording,
      sentCount: sentCount ?? this.sentCount,
      queuedCount: queuedCount ?? this.queuedCount,
      failedCount: failedCount ?? this.failedCount,
      lastSentAt: clearLastSentAt ? null : lastSentAt ?? this.lastSentAt,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }

  bool get hasSession => sessionId != null;
  bool get isTerminalSession =>
      sessionStatus != null &&
      LogisticsTrackingStatus.isTerminal(sessionStatus!);

  /// No session yet → the only lifecycle control is Start.
  bool get canStartSession =>
      !isLoading && !isBusy && sessionStatus == null;

  bool get canPauseSession =>
      !isLoading && !isBusy && sessionStatus == LogisticsTrackingStatus.active;

  bool get canResumeSession =>
      !isLoading && !isBusy && sessionStatus == LogisticsTrackingStatus.paused;

  bool get canCompleteSession =>
      !isLoading &&
      !isBusy &&
      (sessionStatus == LogisticsTrackingStatus.active ||
          sessionStatus == LogisticsTrackingStatus.paused);

  /// Recording is only ever possible while a session is active.
  bool get canToggleRecording =>
      !isLoading && !isBusy && sessionStatus == LogisticsTrackingStatus.active;

  bool get canRetryQueue => !isBusy && queuedCount > 0;

  /// True while any control must stay disabled.
  bool get controlsLocked => isLoading || isBusy;

  String get sessionStatusLabel {
    switch (sessionStatus) {
      case LogisticsTrackingStatus.active:
        return 'Recording';
      case LogisticsTrackingStatus.paused:
        return 'Paused';
      case LogisticsTrackingStatus.completed:
        return 'Completed';
      case LogisticsTrackingStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Not started';
    }
  }
}

final driverTrackingControllerProvider = NotifierProvider.autoDispose.family<
    DriverTrackingController, DriverTrackingState, DriverTrackingTarget>(
  DriverTrackingController.new,
);

class DriverTrackingController extends Notifier<DriverTrackingState> {
  DriverTrackingController(this.target);

  final DriverTrackingTarget target;

  LogisticsRepository? _repository;
  DeviceLocationSource? _deviceLocationSource;
  StreamSubscription<DeviceLocationSample>? _watchSubscription;
  final LogisticsLocationPointQueue _queue = LogisticsLocationPointQueue();

  /// Invalidates every async continuation started before the latest build
  /// or after disposal, so nothing touches `state` once it is unsafe.
  int _generation = 0;
  bool _flushing = false;

  String get _assignmentId => target.assignmentId;

  @override
  DriverTrackingState build() {
    final generation = ++_generation;
    _repository = ref.read(logisticsRepositoryProvider);
    _deviceLocationSource = ref.read(deviceLocationSourceProvider);

    ref.onDispose(_handleDispose);
    ref.listen(connectivityProvider, (previous, next) {
      if (next.value ?? false) _retryQueued();
    });

    _loadExistingSession(generation);
    return DriverTrackingState.initial(_assignmentId);
  }

  void _handleDispose() {
    _generation++;
    _cancelWatch();
  }

  bool _alive(int generation) => generation == _generation;

  // ── Hydration ──────────────────────────────────────────────

  Future<void> _loadExistingSession(int generation) async {
    final repository = _repository;
    if (repository == null) return;
    try {
      final session =
          await repository.fetchLatestTrackingSession(_assignmentId);
      if (!_alive(generation)) return;
      state = state.copyWith(
        sessionId: session?.id,
        sessionStatus: session?.status,
        isLoading: false,
        clearSession: session == null,
      );
    } catch (error) {
      if (!_alive(generation)) return;
      state = state.copyWith(
        isLoading: false,
        lastError: describeTrackingActionError(error),
      );
    }
  }

  // ── Lifecycle transitions (backend RPCs) ───────────────────

  Future<void> start() => _transition(
        name: 'start',
        call: (repository) => repository.startTrackingSession(
          assignmentId: _assignmentId,
        ),
        nextStatus: LogisticsTrackingStatus.active,
        beginRecording: true,
      );

  Future<void> pause() => _transition(
        name: 'pause',
        call: (repository) => repository.pauseTrackingSession(
          trackingSessionId: state.sessionId!,
        ),
        nextStatus: LogisticsTrackingStatus.paused,
        beginRecording: false,
      );

  Future<void> resume() => _transition(
        name: 'resume',
        call: (repository) => repository.resumeTrackingSession(
          trackingSessionId: state.sessionId!,
        ),
        nextStatus: LogisticsTrackingStatus.active,
        beginRecording: true,
      );

  Future<void> complete() => _transition(
        name: 'complete',
        call: (repository) => repository.completeTrackingSession(
          trackingSessionId: state.sessionId!,
        ),
        nextStatus: LogisticsTrackingStatus.completed,
        beginRecording: false,
      );

  Future<void> _transition({
    required String name,
    required Future<String> Function(LogisticsRepository repository) call,
    required String nextStatus,
    required bool beginRecording,
  }) async {
    if (state.controlsLocked) return;
    if (name != 'start' && state.sessionId == null) return;
    if (state.isTerminalSession && name != 'start') return;

    state = state.copyWith(isBusy: true, clearError: true);
    final generation = _generation;

    try {
      final repository = _repository;
      if (repository == null) throw StateError('Repository unavailable.');

      final sessionId = await call(repository);
      if (!_alive(generation)) return;

      state = state.copyWith(
        sessionId: sessionId,
        sessionStatus: nextStatus,
        isBusy: false,
      );
      _refreshRelated(sessionId: sessionId);

      if (beginRecording) {
        await _beginRecording();
      } else {
        _cancelWatch();
        if (_alive(generation)) state = state.copyWith(isRecording: false);
      }
    } catch (error) {
      if (!_alive(generation)) return;
      state = state.copyWith(
        isBusy: false,
        lastError: describeTrackingActionError(error),
      );
    }
  }

  // ── Recording (device permission + GPS) ────────────────────

  /// Requests device permission from an explicit user action and starts
  /// the conservative reading stream when granted.
  Future<void> startRecording() async {
    if (!state.canToggleRecording || state.isRecording) return;
    await _beginRecording();
  }

  /// Stops reading without touching the backend session.
  void stopRecording() {
    _cancelWatch();
    state = state.copyWith(isRecording: false);
  }

  Future<void> _beginRecording() async {
    final generation = _generation;
    final deviceLocationSource = _deviceLocationSource;
    if (deviceLocationSource == null) return;
    if (state.sessionStatus != LogisticsTrackingStatus.active) return;
    if (state.sessionId == null) return;

    final deviceState = await deviceLocationSource.ensurePermission();
    if (!_alive(generation)) return;

    if (deviceState != DeviceLocationState.granted) {
      state = state.copyWith(
        deviceState: deviceState,
        isRecording: false,
        lastError: _deviceMessage(deviceState),
      );
      _cancelWatch();
      return;
    }

    state = state.copyWith(
      deviceState: DeviceLocationState.granted,
      clearError: true,
    );
    _watchSubscription = deviceLocationSource.watch().listen(
          (sample) => _onSample(sample, generation),
          onError: (Object _) {
            if (!_alive(generation)) return;
            state = state.copyWith(
              isRecording: false,
              lastError:
                  'Location readings stopped. Check device location access.',
            );
          },
        );
    if (!_alive(generation)) return;
    state = state.copyWith(isRecording: true);
  }

  void _cancelWatch() {
    _watchSubscription?.cancel();
    _watchSubscription = null;
  }

  void _onSample(DeviceLocationSample sample, int generation) {
    if (!_alive(generation)) return;
    if (state.sessionStatus != LogisticsTrackingStatus.active) return;
    final sessionId = state.sessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    _deliver(
      QueuedLocationPoint(
        // Generated once per physical point and reused on every retry.
        idempotencyKey: generateLocationIdempotencyKey(),
        trackingSessionId: sessionId,
        capturedAt: sample.capturedAt,
        latitude: sample.latitude,
        longitude: sample.longitude,
        accuracy: sample.accuracy,
        speed: sample.speed,
        heading: sample.heading,
        altitude: sample.altitude,
      ),
      generation,
    );
  }

  Future<void> _deliver(
    QueuedLocationPoint point,
    int generation,
  ) async {
    final repository = _repository;
    if (repository == null) return;

    try {
      await _send(repository, point);
      if (!_alive(generation)) return;
      _queue.remove(point.idempotencyKey);
      state = state.copyWith(
        sentCount: state.sentCount + 1,
        queuedCount: _queue.length,
        lastSentAt: DateTime.now(),
        clearError: true,
      );
    } catch (error) {
      // Keep the ORIGINAL idempotency key so a retry can never duplicate
      // the point in logistics.location_points.
      _queue.add(point.withFailedAttempt());
      if (!_alive(generation)) return;
      state = state.copyWith(
        failedCount: state.failedCount + 1,
        queuedCount: _queue.length,
        lastError: describeLocationPointError(error),
      );
    }
  }

  Future<void> _send(
    LogisticsRepository repository,
    QueuedLocationPoint point,
  ) {
    return repository.recordLocationPoint(
      trackingSessionId: point.trackingSessionId,
      idempotencyKey: point.idempotencyKey,
      capturedAt: point.capturedAt,
      latitude: point.latitude,
      longitude: point.longitude,
      accuracy: point.accuracy,
      speed: point.speed,
      heading: point.heading,
      altitude: point.altitude,
    );
  }

  /// Explicit, single-pass retry of the bounded queue. Stops at the first
  /// failure — there is deliberately no tight retry loop.
  Future<void> retryQueued() => _retryQueued();

  Future<void> _retryQueued() async {
    if (_flushing) return;
    if (_queue.isEmpty) return;

    final repository = _repository;
    if (repository == null) return;

    final generation = _generation;
    _flushing = true;
    try {
      for (final point in List<QueuedLocationPoint>.of(_queue.pending)) {
        if (!_alive(generation)) return;
        try {
          await _send(repository, point);
        } catch (error) {
          if (!_alive(generation)) return;
          _queue.add(point.withFailedAttempt());
          state = state.copyWith(
            queuedCount: _queue.length,
            lastError: describeLocationPointError(error),
          );
          // Stop at the first failure.
          return;
        }
        if (!_alive(generation)) return;
        _queue.remove(point.idempotencyKey);
        state = state.copyWith(
          sentCount: state.sentCount + 1,
          queuedCount: _queue.length,
          lastSentAt: DateTime.now(),
          clearError: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      _flushing = false;
    }
  }

  // ── Cache refresh ──────────────────────────────────────────

  void _refreshRelated({String? sessionId}) {
    ref.invalidate(logisticsDashboardProvider);
    ref.invalidate(logisticsTrackingSessionsProvider);
    final shipmentId = target.shipmentId;
    if (shipmentId != null && shipmentId.isNotEmpty) {
      ref.invalidate(logisticsShipmentDetailProvider(shipmentId));
    }
    if (sessionId != null && sessionId.isNotEmpty) {
      ref.invalidate(logisticsTrackingSessionDetailProvider(sessionId));
    }
  }

  static String _deviceMessage(DeviceLocationState deviceState) {
    switch (deviceState) {
      case DeviceLocationState.servicesDisabled:
        return 'Location services are switched off on this device.';
      case DeviceLocationState.permanentlyDenied:
        return 'Location access is blocked. Enable it in device settings '
            'to record this shipment.';
      case DeviceLocationState.denied:
        return 'Location permission was declined.';
      case DeviceLocationState.unavailable:
        return 'Device location is not available right now.';
      case DeviceLocationState.granted:
      case DeviceLocationState.unknown:
        return 'Device location is not available right now.';
    }
  }
}
