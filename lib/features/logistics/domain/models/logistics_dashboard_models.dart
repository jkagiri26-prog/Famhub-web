/// ============================================================
/// LOGISTICS DASHBOARD MODELS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/domain/models/ = domain models
///
/// ✅ Responsibilities:
///   - Plain read models for the Logistics dashboard.
///   - Map rows coming from `logistics.*` into typed values.
///
/// ❌ Does NOT:
///   - Access Supabase
///   - Hold UI state
/// ============================================================
library;

/// Lifecycle status of `logistics.shipments.status`.
abstract final class LogisticsShipmentStatus {
  /// Statuses that still represent an in-flight shipment.
  static const List<String> active = [
    'requested',
    'accepted',
    'assigned',
    'pickup_scheduled',
    'picked_up',
    'in_transit',
    'arrived',
  ];

  static const String delivered = 'delivered';
  static const String partiallyDelivered = 'partially_delivered';
  static const String cancelled = 'cancelled';
}

/// Lifecycle status of `logistics.assignments.status`.
abstract final class LogisticsAssignmentStatus {
  static const String assigned = 'assigned';
  static const String accepted = 'accepted';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String rejected = 'rejected';
  static const String reassigned = 'reassigned';

  /// Assignments that are still expected to move a shipment.
  static const List<String> active = [assigned, accepted, inProgress];
}

/// Status of `logistics.tracking_sessions.status`.
abstract final class LogisticsTrackingStatus {
  static const String active = 'active';
  static const String paused = 'paused';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';

  /// Statuses a driver may still transition away from.
  static const List<String> transitionable = [active, paused];

  /// Session statuses that can no longer be started/paused/resumed.
  static const List<String> terminal = [completed, cancelled];

  static bool isTerminal(String status) => terminal.contains(status);
}

/// ============================================================
/// SHIPMENT (read model)
/// ============================================================
class LogisticsShipment {
  final String id;
  final String status;
  final String? trackingNumber;
  final String? carrier;
  final DateTime? updatedAt;

  const LogisticsShipment({
    required this.id,
    required this.status,
    this.trackingNumber,
    this.carrier,
    this.updatedAt,
  });

  bool get isActive => LogisticsShipmentStatus.active.contains(status);

  /// Human readable label derived from the backend status value.
  String get statusLabel => status
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  factory LogisticsShipment.fromMap(Map<String, dynamic> map) {
    return LogisticsShipment(
      id: map['id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      trackingNumber: map['tracking_number']?.toString(),
      carrier: map['carrier']?.toString(),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }
}

/// ============================================================
/// ASSIGNMENT (read model)
/// ============================================================
class LogisticsAssignment {
  final String id;
  final String shipmentId;
  final String status;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;

  final String? providerEntityId;
  final String? driverProfileId;
  final String? vehicleId;

  /// Best-effort display labels resolved from related tables.
  /// Null when the related row is not readable under RLS.
  final String? providerName;
  final String? driverName;
  final String? vehicleLabel;

  const LogisticsAssignment({
    required this.id,
    required this.shipmentId,
    required this.status,
    this.assignedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.notes,
    this.providerEntityId,
    this.driverProfileId,
    this.vehicleId,
    this.providerName,
    this.driverName,
    this.vehicleLabel,
  });

  bool get isActive => LogisticsAssignmentStatus.active.contains(status);

  /// Assigned but not yet accepted by the transport provider.
  bool get isPending =>
      status == LogisticsAssignmentStatus.assigned && acceptedAt == null;

  /// Attachment a tracking session can be started from.
  bool get isTrackable => LogisticsAssignmentStatus.active.contains(status);

  LogisticsAssignment withResolvedNames({
    String? providerName,
    String? driverName,
    String? vehicleLabel,
  }) {
    return LogisticsAssignment(
      id: id,
      shipmentId: shipmentId,
      status: status,
      assignedAt: assignedAt,
      acceptedAt: acceptedAt,
      startedAt: startedAt,
      completedAt: completedAt,
      notes: notes,
      providerEntityId: providerEntityId,
      driverProfileId: driverProfileId,
      vehicleId: vehicleId,
      providerName: providerName ?? this.providerName,
      driverName: driverName ?? this.driverName,
      vehicleLabel: vehicleLabel ?? this.vehicleLabel,
    );
  }

  factory LogisticsAssignment.fromMap(Map<String, dynamic> map) {
    return LogisticsAssignment(
      id: map['id']?.toString() ?? '',
      shipmentId: map['shipment_id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      assignedAt: _parseDateTime(map['assigned_at']),
      acceptedAt: _parseDateTime(map['accepted_at']),
      startedAt: _parseDateTime(map['started_at']),
      completedAt: _parseDateTime(map['completed_at']),
      notes: map['notes']?.toString(),
      providerEntityId: map['provider_entity_id']?.toString(),
      driverProfileId: map['driver_profile_id']?.toString(),
      vehicleId: map['vehicle_id']?.toString(),
    );
  }
}

/// ============================================================
/// TRACKING SESSION (read model)
/// ============================================================
class LogisticsTrackingSession {
  final String id;
  final String shipmentId;
  final String assignmentId;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? lastLocationCapturedAt;

  const LogisticsTrackingSession({
    required this.id,
    required this.shipmentId,
    this.assignmentId = '',
    required this.status,
    this.startedAt,
    this.endedAt,
    this.lastLocationCapturedAt,
  });

  bool get isActive => status == LogisticsTrackingStatus.active;
  bool get isPaused => status == LogisticsTrackingStatus.paused;
  bool get isTerminal => LogisticsTrackingStatus.isTerminal(status);

  factory LogisticsTrackingSession.fromMap(Map<String, dynamic> map) {
    return LogisticsTrackingSession(
      id: map['id']?.toString() ?? '',
      shipmentId: map['shipment_id']?.toString() ?? '',
      assignmentId: map['assignment_id']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      startedAt: _parseDateTime(map['started_at']),
      endedAt: _parseDateTime(map['ended_at']),
      lastLocationCapturedAt: _parseDateTime(map['last_location_captured_at']),
    );
  }
}

/// ============================================================
/// DASHBOARD SNAPSHOT (aggregate read model)
/// ============================================================
///
/// One bounded payload for the whole Logistics dashboard.
/// Every list is already limited by the repository so the
/// dashboard never downloads full shipment history.
class LogisticsDashboardSnapshot {
  final List<LogisticsShipment> activeShipments;
  final List<LogisticsShipment> recentShipments;
  final List<LogisticsAssignment> assignments;
  final List<LogisticsTrackingSession> activeTrackingSessions;

  /// True when the repository truncated any list at its bound.
  final bool isTruncated;

  const LogisticsDashboardSnapshot({
    this.activeShipments = const [],
    this.recentShipments = const [],
    this.assignments = const [],
    this.activeTrackingSessions = const [],
    this.isTruncated = false,
  });

  static const LogisticsDashboardSnapshot empty = LogisticsDashboardSnapshot();

  List<LogisticsAssignment> get activeAssignments =>
      assignments.where((a) => a.isActive).toList();

  List<LogisticsAssignment> get pendingAssignments =>
      assignments.where((a) => a.isPending).toList();

  bool get hasActiveTracking => activeTrackingSessions.isNotEmpty;

  /// Tracking sessions exist for an assignment that could be tracked.
  bool get trackingAvailable => activeAssignments.isNotEmpty;

  DateTime? get latestTrackingCapture {
    DateTime? latest;
    for (final session in activeTrackingSessions) {
      final captured = session.lastLocationCapturedAt;
      if (captured == null) continue;
      if (latest == null || captured.isAfter(latest)) latest = captured;
    }
    return latest;
  }

  bool get isEmpty =>
      activeShipments.isEmpty &&
      recentShipments.isEmpty &&
      assignments.isEmpty &&
      activeTrackingSessions.isEmpty;
}

DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
