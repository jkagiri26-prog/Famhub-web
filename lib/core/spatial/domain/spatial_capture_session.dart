/// ============================================================
/// SPATIAL CAPTURE SESSION — DOMAIN MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/spatial/domain/ = spatial domain models
///
/// Mirrors the backend `spatial.spatial_capture_sessions` table.
/// Represents a GPS capture session for recording field boundaries.
///
/// ✅ Responsibilities:
///   - Define the immutable capture session model
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
/// CAPTURE SESSION
/// ============================================================
///
/// Immutable model representing a GPS capture session.
///
/// Backend table: `spatial.spatial_capture_sessions`
///
/// status values: 'active', 'completed', 'cancelled'
/// mode values: 'manual', 'continuous', 'semi_automatic'
/// ============================================================
class CaptureSession {
  /// Primary identifier (uuid)
  final String id;

  /// Foreign key to the spatial asset being captured
  final String? assetId;

  /// Session status: 'active', 'completed', 'cancelled'
  final String status;

  /// Capture mode: 'manual', 'continuous', 'semi_automatic'
  final String mode;

  /// When the session started (milliseconds since epoch)
  final int? startedAt;

  /// When the session was completed (milliseconds since epoch)
  final int? completedAt;

  const CaptureSession({
    required this.id,
    this.assetId,
    this.status = 'active',
    this.mode = 'manual',
    this.startedAt,
    this.completedAt,
  });

  /// ============================================================
  /// COMPUTED PROPERTIES
  /// ============================================================

  /// Whether the session is currently active
  bool get isActive => status == 'active';

  /// Whether the session is completed
  bool get isCompleted => status == 'completed';

  /// Whether the session is cancelled
  bool get isCancelled => status == 'cancelled';

  /// ============================================================
  /// COPY WITH
  /// ============================================================
  CaptureSession copyWith({
    String? id,
    String? assetId,
    String? status,
    String? mode,
    int? startedAt,
    int? completedAt,
  }) {
    return CaptureSession(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// ============================================================
  /// SERIALIZATION
  /// ============================================================

  /// Serialize to a map
  Map<String, dynamic> toJson() => {
        'id': id,
        'asset_id': assetId,
        'status': status,
        'mode': mode,
        'started_at': startedAt,
        'completed_at': completedAt,
      };

  /// Deserialize from a map
  factory CaptureSession.fromJson(Map<String, dynamic> json) =>
      CaptureSession(
        id: json['id'] as String,
        assetId: (json['asset_id'] ?? json['assetId']) as String?,
        status: (json['status'] ?? 'active') as String,
        mode: (json['mode'] ?? 'manual') as String,
        startedAt: (json['started_at'] ?? json['startedAt']) as int?,
        completedAt: (json['completed_at'] ?? json['completedAt']) as int?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureSession &&
          id == other.id &&
          runtimeType == other.runtimeType;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CaptureSession($id, status: $status, mode: $mode)';
}
