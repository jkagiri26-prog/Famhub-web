/// ============================================================
/// CONFLICT SOURCE
/// ============================================================
///
/// Defines the origin of a runtime event.
///
/// Priority is handled by ConflictResolver.
/// ============================================================
library;

enum ConflictSource {
  realtime,
  local,
  hydration,
  patch,
}

/// ============================================================
/// CONFLICT EVENT
/// ============================================================
///
/// Immutable runtime event used by:
///
/// Realtime → ConflictBuffer → ConflictResolver → Pipeline
///
/// DESIGN:
/// - Immutable
/// - Lightweight
/// - Deterministic equality
/// - Safe diagnostics
/// ============================================================

class ConflictEvent {
  const ConflictEvent({
    required this.entityId,
    required this.source,
    required this.timestamp,
    required this.payload,
  });

  /// ============================================================
  /// ENTITY IDENTIFIER
  /// ============================================================

  final String entityId;

  /// ============================================================
  /// EVENT SOURCE
  /// ============================================================

  final ConflictSource source;

  /// ============================================================
  /// EVENT TIMESTAMP
  /// ============================================================

  final DateTime timestamp;

  /// ============================================================
  /// EVENT PAYLOAD
  /// ============================================================

  final Map<String, dynamic> payload;

  /// ============================================================
  /// DIAGNOSTICS
  /// ============================================================

  @override
  String toString() {
    return 'ConflictEvent('
        'entityId: $entityId, '
        'source: $source, '
        'timestamp: $timestamp'
        ')';
  }

  /// ============================================================
  /// VALUE EQUALITY
  /// ============================================================
  ///
  /// Allows deterministic comparison and deduplication.
  /// Payload intentionally excluded because conflict resolution
  /// is based on identity, source and event ordering.
  /// ============================================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is ConflictEvent &&
        other.entityId == entityId &&
        other.source == source &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(
        entityId,
        source,
        timestamp,
      );
}