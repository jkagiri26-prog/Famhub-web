/// ============================================================
/// LOGISTICS DETAIL MODELS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/domain/models/ = domain models
///
/// ✅ Responsibilities:
///   - Plain read models for shipment detail, tracking history and
///     transport administration options.
///
/// ❌ Does NOT:
///   - Access Supabase
///   - Hold UI state
/// ============================================================
library;

import 'logistics_dashboard_models.dart';

// ── Shipment items ─────────────────────────────────────────────

class LogisticsShipmentItem {
  final String id;
  final String shipmentId;
  final String? itemId;
  final String? variantId;
  final String? unitId;
  final num quantity;
  final num? weight;
  final int? packageCount;
  final String? notes;
  final DateTime? createdAt;

  /// Resolved display labels — null when the related row is not readable.
  final String? itemName;
  final String? variantName;
  final String? unitName;

  const LogisticsShipmentItem({
    required this.id,
    required this.shipmentId,
    required this.quantity,
    this.itemId,
    this.variantId,
    this.unitId,
    this.weight,
    this.packageCount,
    this.notes,
    this.createdAt,
    this.itemName,
    this.variantName,
    this.unitName,
  });

  factory LogisticsShipmentItem.fromMap(Map<String, dynamic> map) {
    return LogisticsShipmentItem(
      id: map['id']?.toString() ?? '',
      shipmentId: map['shipment_id']?.toString() ?? '',
      itemId: map['item_id']?.toString(),
      variantId: map['variant_id']?.toString(),
      unitId: map['unit_id']?.toString(),
      quantity: (map['quantity'] as num?) ?? 0,
      weight: map['weight'] as num?,
      packageCount: (map['package_count'] as num?)?.toInt(),
      notes: map['notes']?.toString(),
      createdAt: _parseDateTime(map['created_at']),
      itemName: map['item_name']?.toString(),
      variantName: map['variant_name']?.toString(),
      unitName: map['unit_name']?.toString(),
    );
  }

  LogisticsShipmentItem withResolvedNames({
    String? itemName,
    String? variantName,
    String? unitName,
  }) {
    return LogisticsShipmentItem(
      id: id,
      shipmentId: shipmentId,
      quantity: quantity,
      itemId: itemId,
      variantId: variantId,
      unitId: unitId,
      weight: weight,
      packageCount: packageCount,
      notes: notes,
      createdAt: createdAt,
      itemName: itemName ?? this.itemName,
      variantName: variantName ?? this.variantName,
      unitName: unitName ?? this.unitName,
    );
  }

  /// `Tomatoes — Hybrid Seed  ·  40 kg`
  String get displayName {
    final base = [itemName, if (variantName != null) variantName]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' — ');
    if (base.isNotEmpty) return base;
    return 'Shipment item ${id.isEmpty ? '' : '#$id'}'.trim();
  }

  String get quantityLabel {
    final unit = (unitName?.isNotEmpty == true) ? ' ${unitName!.trim()}' : '';
    final weightLabel = weight == null ? '' : ', $weight kg';
    return '${_formatNumber(quantity)}$unit$weightLabel';
  }

  String get packageLabel => packageCount == null
      ? ''
      : '$packageCount package${packageCount == 1 ? '' : 's'}';
}

// ── Stops ──────────────────────────────────────────────────────

/// Lifecycle status of `logistics.stops.status`.
abstract final class LogisticsStopStatus {
  static const String planned = 'planned';
  static const String arrived = 'arrived';
  static const String departed = 'departed';
  static const String completed = 'completed';
  static const String skipped = 'skipped';
  static const String failed = 'failed';
}

class LogisticsStop {
  final String id;
  final String shipmentId;
  final int sequenceNumber;
  final String stopType;
  final String? locationId;
  final String status;
  final DateTime? scheduledArrival;
  final DateTime? actualArrival;
  final DateTime? scheduledDeparture;
  final DateTime? actualDeparture;
  final String? notes;

  /// Best-effort location label — null when not readable.
  final String? locationName;

  const LogisticsStop({
    required this.id,
    required this.shipmentId,
    required this.sequenceNumber,
    required this.stopType,
    required this.status,
    this.locationId,
    this.scheduledArrival,
    this.actualArrival,
    this.scheduledDeparture,
    this.actualDeparture,
    this.notes,
    this.locationName,
  });

  factory LogisticsStop.fromMap(Map<String, dynamic> map) {
    return LogisticsStop(
      id: map['id']?.toString() ?? '',
      shipmentId: map['shipment_id']?.toString() ?? '',
      sequenceNumber: (map['sequence_number'] as num?)?.toInt() ?? 0,
      stopType: map['stop_type']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      locationId: map['location_id']?.toString(),
      scheduledArrival: _parseDateTime(map['scheduled_arrival']),
      actualArrival: _parseDateTime(map['actual_arrival']),
      scheduledDeparture: _parseDateTime(map['scheduled_departure']),
      actualDeparture: _parseDateTime(map['actual_departure']),
      notes: map['notes']?.toString(),
      locationName: map['location_name']?.toString(),
    );
  }

  LogisticsStop withLocationName(String? name) => LogisticsStop(
        id: id,
        shipmentId: shipmentId,
        sequenceNumber: sequenceNumber,
        stopType: stopType,
        status: status,
        locationId: locationId,
        scheduledArrival: scheduledArrival,
        actualArrival: actualArrival,
        scheduledDeparture: scheduledDeparture,
        actualDeparture: actualDeparture,
        notes: notes,
        locationName: name ?? locationName,
      );

  bool get isPickup => stopType == 'pickup';
  bool get isDropoff => stopType == 'dropoff';

  String get stopTypeLabel {
    switch (stopType) {
      case 'pickup':
        return 'Pickup';
      case 'dropoff':
        return 'Drop-off';
      case 'transfer':
        return 'Transfer';
      default:
        return stopType.isEmpty ? 'Stop' : stopType;
    }
  }

  String get statusLabel => status
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  String get locationLabel =>
      locationName?.isNotEmpty == true ? locationName! : 'Location not set';
}

// ── Tracking events ────────────────────────────────────────────

class LogisticsTrackingEvent {
  final String id;
  final String shipmentId;
  final String eventType;
  final DateTime? occurredAt;
  final String? notes;

  const LogisticsTrackingEvent({
    required this.id,
    required this.shipmentId,
    required this.eventType,
    this.occurredAt,
    this.notes,
  });

  factory LogisticsTrackingEvent.fromMap(Map<String, dynamic> map) {
    return LogisticsTrackingEvent(
      id: map['id']?.toString() ?? '',
      shipmentId: map['shipment_id']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? '',
      occurredAt: _parseDateTime(map['occurred_at']),
      notes: map['notes']?.toString(),
    );
  }

  String get eventTypeLabel => eventType
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

// ── Location points ────────────────────────────────────────────

class LogisticsLocationPoint {
  final String id;
  final String trackingSessionId;
  final DateTime? capturedAt;
  final DateTime? receivedAt;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;

  const LogisticsLocationPoint({
    required this.id,
    required this.trackingSessionId,
    required this.latitude,
    required this.longitude,
    this.capturedAt,
    this.receivedAt,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
  });

  factory LogisticsLocationPoint.fromMap(Map<String, dynamic> map) {
    return LogisticsLocationPoint(
      id: map['id']?.toString() ?? '',
      trackingSessionId: map['tracking_session_id']?.toString() ?? '',
      capturedAt: _parseDateTime(map['captured_at']),
      receivedAt: _parseDateTime(map['received_at']),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
    );
  }

  bool get hasValidCoordinates =>
      latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;

  String get coordinatesLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

// ── Aggregates ─────────────────────────────────────────────────

/// One bounded payload for the shipment detail experience.
class LogisticsShipmentDetail {
  final LogisticsShipment shipment;
  final List<LogisticsShipmentItem> items;
  final List<LogisticsStop> stops;
  final List<LogisticsAssignment> assignments;
  final List<LogisticsTrackingSession> trackingSessions;
  final List<LogisticsTrackingEvent> events;

  /// True when any list hit its bound.
  final bool isTruncated;

  const LogisticsShipmentDetail({
    required this.shipment,
    this.items = const [],
    this.stops = const [],
    this.assignments = const [],
    this.trackingSessions = const [],
    this.events = const [],
    this.isTruncated = false,
  });

  /// First planned/executed pickup by sequence number.
  LogisticsStop? get originStop {
    for (final stop in stops) {
      if (stop.isPickup) return stop;
    }
    return stops.isEmpty ? null : stops.first;
  }

  /// Last planned/executed drop-off by sequence number.
  LogisticsStop? get destinationStop {
    for (final stop in stops.reversed) {
      if (stop.isDropoff) return stop;
    }
    return stops.isEmpty ? null : stops.last;
  }

  LogisticsTrackingSession? sessionForAssignment(String assignmentId) {
    for (final session in trackingSessions) {
      if (session.assignmentId == assignmentId) return session;
    }
    return null;
  }

  LogisticsAssignment? get primaryTrackableAssignment {
    for (final assignment in assignments) {
      if (assignment.isTrackable) return assignment;
    }
    return assignments.isEmpty ? null : assignments.first;
  }
}

/// Bounded location history for one tracking session.
class LogisticsTrackingSessionDetail {
  final LogisticsTrackingSession session;
  final List<LogisticsLocationPoint> points;
  final bool isTruncated;

  const LogisticsTrackingSessionDetail({
    required this.session,
    this.points = const [],
    this.isTruncated = false,
  });

  LogisticsLocationPoint? get latestPoint =>
      points.isEmpty ? null : points.first;

  DateTime? get latestCapturedAt => latestPoint?.capturedAt;
}

// ── Transport administration options ───────────────────────────

class LogisticsProviderOption {
  final String id;
  final String name;

  const LogisticsProviderOption({required this.id, required this.name});
}

class LogisticsDriverOption {
  final String id;
  final String name;

  const LogisticsDriverOption({required this.id, required this.name});
}

class LogisticsVehicleOption {
  final String id;
  final String registrationRef;
  final String vehicleType;

  const LogisticsVehicleOption({
    required this.id,
    required this.registrationRef,
    this.vehicleType = '',
  });

  String get label => vehicleType.isEmpty
      ? registrationRef
      : '$registrationRef · $vehicleType';
}

/// Best-effort candidate lists for the assign-transport dialog.
///
/// Every list is bounded and best-effort: a read that the backend does
/// not allow simply yields an empty list, and the dialog falls back to
/// manual id entry. RLS stays authoritative.
class LogisticsTransportOptions {
  final List<LogisticsProviderOption> providers;
  final List<LogisticsDriverOption> drivers;
  final List<LogisticsVehicleOption> vehicles;

  const LogisticsTransportOptions({
    this.providers = const [],
    this.drivers = const [],
    this.vehicles = const [],
  });

  bool get isEmpty =>
      providers.isEmpty && drivers.isEmpty && vehicles.isEmpty;

  static const LogisticsTransportOptions empty = LogisticsTransportOptions();
}

// ── Helpers ────────────────────────────────────────────────────

String _formatNumber(num value) {
  if (value == value.roundToDouble()) {
    final asInt = value.toInt();
    if (asInt.abs() < 1000000) return asInt.toString();
  }
  return value.toString();
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
