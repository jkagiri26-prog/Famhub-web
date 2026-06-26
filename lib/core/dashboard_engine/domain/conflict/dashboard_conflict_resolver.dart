// lib/core/dashboard_engine/domain/conflict/dashboard_conflict_resolver.dart

import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_event.dart';

/// ============================================================
/// CONFLICT RESOLVER (PURE DOMAIN LOGIC)
/// ============================================================
///
/// RULES:
/// - Stateless
/// - Deterministic
/// - No mutation
/// - No caching
/// - No buffering
/// ============================================================

class ConflictResolver {
  const ConflictResolver();

  /// Resolves a batch of conflict events into a final ordered result.
  ///
  /// This is PURE logic only — no side effects.
  List<ConflictEvent> resolveBatch(List<ConflictEvent> events) {
    if (events.isEmpty) return const [];

    /// ============================================================
    /// DEFAULT STRATEGY:
    /// - Latest timestamp wins per entity
    /// - Stable ordering preserved
    /// ============================================================

    final Map<String, ConflictEvent> latestByEntity = {};

    for (final event in events) {
      final existing = latestByEntity[event.entityId];

      if (existing == null) {
        latestByEntity[event.entityId] = event;
        continue;
      }

      /// Keep the most recent event (deterministic rule)
      if (event.timestamp.isAfter(existing.timestamp)) {
        latestByEntity[event.entityId] = event;
      }
    }

    /// Return deterministic ordering (by timestamp)
    final resolved = latestByEntity.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return resolved;
  }
}