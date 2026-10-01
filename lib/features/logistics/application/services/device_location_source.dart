/// ============================================================
/// DEVICE LOCATION SOURCE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/application/services/ = application services
///
/// ✅ Responsibilities:
///   - Thin abstraction over the device location stack so the driver
///     tracking controller can be unit tested without a platform
///     channel.
///   - Request device location permission ONLY from an explicit user
///     action (Start / Resume). Never on app open, never on page load.
///   - Produce a conservative, throttled stream: a distance filter
///     plus a minimum interval between emitted readings so shipment
///     tracking never samples at a high frequency.
///
/// ❌ Does NOT:
///   - Start a background tracking service
///   - Send anything to the backend
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Resolution of the device location permission for this app.
enum DeviceLocationState {
  /// Permission has not been requested yet.
  unknown,

  /// Location may be read while the app is in use.
  granted,

  /// The user denied the request — a later request may still prompt.
  denied,

  /// The user denied the request and told the OS not to ask again.
  permanentlyDenied,

  /// Location services are switched off on the device.
  servicesDisabled,

  /// The platform could not report a permission state.
  unavailable,
}

/// One device reading handed to the tracking controller.
class DeviceLocationSample {
  final DateTime capturedAt;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;

  const DeviceLocationSample({
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
  });
}

abstract class DeviceLocationSource {
  /// Resolves (and on first use requests) the device location permission.
  ///
  /// Must only be called from an explicit user action.
  Future<DeviceLocationState> ensurePermission();

  /// Conservative reading stream — already distance- and time-filtered.
  Stream<DeviceLocationSample> watch();
}

/// Minimum distance between readings, in metres.
const int kLogisticsLocationDistanceFilterMeters = 100;

/// Minimum time between readings, even while moving.
const Duration kLogisticsLocationMinInterval = Duration(seconds: 60);

final deviceLocationSourceProvider = Provider<DeviceLocationSource>((ref) {
  return GeolocatorDeviceLocationSource();
});

/// geolocator-backed implementation used in the running app.
class GeolocatorDeviceLocationSource implements DeviceLocationSource {
  DateTime? _lastEmitted;

  @override
  Future<DeviceLocationState> ensurePermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return DeviceLocationState.servicesDisabled;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return DeviceLocationState.granted;
      }
      if (permission == LocationPermission.denied) {
        return DeviceLocationState.denied;
      }
      if (permission == LocationPermission.deniedForever) {
        return DeviceLocationState.permanentlyDenied;
      }
      return DeviceLocationState.unavailable;
    } catch (_) {
      return DeviceLocationState.unavailable;
    }
  }

  @override
  Stream<DeviceLocationSample> watch() {
    _lastEmitted = null;
    final readings = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: kLogisticsLocationDistanceFilterMeters,
      ),
    );
    return _throttle(readings.map(_toSample));
  }

  Stream<DeviceLocationSample> _throttle(
    Stream<DeviceLocationSample> source,
  ) async* {
    await for (final sample in source) {
      final last = _lastEmitted;
      if (last != null &&
          sample.capturedAt.difference(last) < kLogisticsLocationMinInterval) {
        continue;
      }
      _lastEmitted = sample.capturedAt;
      yield sample;
    }
  }

  DeviceLocationSample _toSample(Position position) {
    return DeviceLocationSample(
      capturedAt: position.timestamp,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: _nonNegative(position.speed),
      heading: _nonNegative(position.heading),
      altitude: _nonNegative(position.altitude),
    );
  }

  double? _nonNegative(double? value) =>
      value == null || value.isNaN || value < 0 ? null : value;
}
