/// ============================================================
/// SPATIAL CAPTURE POINT — DOMAIN MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/domain/ = spatial domain models
///
/// Mirrors the backend `spatial.spatial_capture_points` table.
/// Represents a single GPS coordinate point recorded during a capture session.
///
/// ✅ Responsibilities:
///   - Define the immutable capture point model
///   - Mirror backend schema exactly
///   - Pure Dart — no Flutter imports
///
/// ❌ Does NOT:
///   - Import Flutter
///   - Contain business logic
///   - Contain UI
/// ============================================================
library;

/// ============================================================
/// CAPTURE POINT
/// ============================================================
///
/// Immutable model representing a single GPS coordinate point.
///
/// Backend table: `spatial.spatial_capture_points`
///
/// Constraints:
///   latitude: -90 to 90
///   longitude: -180 to 180
/// ============================================================
class CapturePoint {
  /// Primary identifier (uuid)
  final String id;

  /// Foreign key to the capture session
  final String sessionId;

  /// Latitude (-90 to 90)
  final double latitude;

  /// Longitude (-180 to 180)
  final double longitude;

  /// GPS accuracy in meters
  final double? accuracyMeters;

  /// Sequence number within the session
  final int sequence;

  /// When the point was recorded (milliseconds since epoch)
  final int? recordedAt;

  const CapturePoint({
    required this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.sequence = 0,
    this.recordedAt,
  });

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  CapturePoint copyWith({
    String? id,
    String? sessionId,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    int? sequence,
    int? recordedAt,
  }) {
    return CapturePoint(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      sequence: sequence ?? this.sequence,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  /// ============================================================
  /// SERIALIZATION
  /// ============================================================

  /// Serialize to a map
  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracyMeters,
        'sequence_no': sequence,
        'recorded_at': recordedAt,
      };

  /// Deserialize from a map
  factory CapturePoint.fromJson(Map<String, dynamic> json) =>
      CapturePoint(
        id: json['id'] as String,
        sessionId: (json['session_id'] ?? json['sessionId']) as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        accuracyMeters:
            (json['accuracy_meters'] ?? json['accuracyMeters'] as num?)
                ?.toDouble(),
        sequence: (json['sequence_no'] ?? json['sequence'] ?? 0) as int,
        recordedAt:
            (json['recorded_at'] ?? json['recordedAt']) as int?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapturePoint &&
          id == other.id &&
          runtimeType == other.runtimeType;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CapturePoint($id @ ($latitude, $longitude) [seq:$sequence])';
}
