/// ============================================================
/// LOGISTICS — BOUNDED LOCATION POINT QUEUE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/application/services/ = application services
///
/// ✅ Responsibilities:
///   - Hold a small, bounded number of location points that could not
///     be delivered yet.
///   - Keep the original idempotency key on every retry so a retry can
///     never create a duplicate point in `logistics.location_points`.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - `logistics.record_location_point` stays the only GPS write path.
///   - No direct INSERT into `logistics.location_points`.
///
/// ❌ Does NOT:
///   - Persist to disk (documented limitation: this queue lives for the
///     session only and is deliberately small — no sync framework)
///   - Retry on a timer or in a loop
/// ============================================================
library;

import 'dart:math';

/// One location point waiting to reach the backend.
class QueuedLocationPoint {
  final String idempotencyKey;
  final String trackingSessionId;
  final DateTime capturedAt;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;

  /// How many delivery attempts have failed for this point.
  final int attempts;

  const QueuedLocationPoint({
    required this.idempotencyKey,
    required this.trackingSessionId,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.attempts = 0,
  });

  QueuedLocationPoint withFailedAttempt() => QueuedLocationPoint(
        idempotencyKey: idempotencyKey,
        trackingSessionId: trackingSessionId,
        capturedAt: capturedAt,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        speed: speed,
        heading: heading,
        altitude: altitude,
        attempts: attempts + 1,
      );
}

/// Small FIFO buffer of undelivered location points.
class LogisticsLocationPointQueue {
  LogisticsLocationPointQueue({this.maxSize = 20})
      : assert(maxSize > 0, 'maxSize must be positive');

  /// Upper bound — the oldest point is evicted once the cap is reached.
  final int maxSize;

  final List<QueuedLocationPoint> _items = [];

  /// Oldest first.
  List<QueuedLocationPoint> get pending => List.unmodifiable(_items);

  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  bool get isFull => _items.length >= maxSize;

  /// Points that still need to reach the backend.
  Iterable<QueuedLocationPoint> get retryable => _items;

  /// Adds [point], replacing any earlier entry with the same idempotency
  /// key. Returns the point that was evicted to stay within [maxSize],
  /// or null.
  QueuedLocationPoint? add(QueuedLocationPoint point) {
    final existingIndex =
        _items.indexWhere((item) => item.idempotencyKey == point.idempotencyKey);
    if (existingIndex >= 0) {
      _items.removeAt(existingIndex);
      _items.add(point);
      return null;
    }

    QueuedLocationPoint? evicted;
    if (_items.length >= maxSize) {
      evicted = _items.removeAt(0);
    }
    _items.add(point);
    return evicted;
  }

  /// Removes a point after a successful delivery. Returns true when the
  /// point was present.
  bool remove(String idempotencyKey) {
    final index =
        _items.indexWhere((item) => item.idempotencyKey == idempotencyKey);
    if (index < 0) return false;
    _items.removeAt(index);
    return true;
  }

  void clear() => _items.clear();
}

/// Generates an RFC 4122 version 4 UUID used as the idempotency key for a
/// single physical location point. The key is generated once when the
/// point is captured and reused verbatim on every retry.
///
/// Pass a seeded [Random] in tests for deterministic keys.
String generateLocationIdempotencyKey([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => source.nextInt(256));

  // RFC 4122 version 4 (random) + variant 10xx.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
