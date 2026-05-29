import 'dashboard_conflict_event.dart';

/// ============================================================
/// CONFLICT RESOLVER (HARDENED CORE)
/// ============================================================
///
/// GUARANTEES:
/// - Fully deterministic resolution
/// - No input mutation
/// - Stable ordering under identical timestamps
/// - Batch-safe grouping
/// - Safe fallback behavior
/// ============================================================

class ConflictResolver {
  const ConflictResolver();

  /// ------------------------------------------------------------
  /// SOURCE PRIORITY MAP
  /// ------------------------------------------------------------
  static const Map<ConflictSource, int> _priority = {
    ConflictSource.local: 3,
    ConflictSource.realtime: 2,
    ConflictSource.hydration: 1,
    ConflictSource.patch: 0,
  };

  /// ============================================================
  /// RESOLVE SINGLE ENTITY GROUP
  /// ============================================================
  ConflictEvent resolve(List<ConflictEvent> events) {
    if (events.isEmpty) {
      throw StateError('Cannot resolve empty conflict set.');
    }

    final sorted = List<ConflictEvent>.of(events);

    sorted.sort((a, b) {
      final priorityDiff =
          (_priority[b.source] ?? 0) -
          (_priority[a.source] ?? 0);

      if (priorityDiff != 0) return priorityDiff;

      final timeDiff = b.timestamp.compareTo(a.timestamp);
      if (timeDiff != 0) return timeDiff;

      /// FINAL TIE-BREAKER (ensures deterministic ordering)
      return a.entityId.compareTo(b.entityId);
    });

    return sorted.first;
  }

  /// ============================================================
  /// RESOLVE BATCH (ENTITY-GROUPED)
  /// ============================================================
  List<ConflictEvent> resolveBatch(List<ConflictEvent> events) {
    if (events.isEmpty) return const [];

    final Map<String, List<ConflictEvent>> grouped = {};

    /// SAFE GROUPING (no mutation of input list)
    for (final event in events) {
      grouped.putIfAbsent(event.entityId, () => <ConflictEvent>[]).add(event);
    }

    final List<ConflictEvent> resolved = [];

    for (final group in grouped.values) {
      resolved.add(resolve(group));
    }

    /// FINAL SORT = stable output order for pipeline consumption
    resolved.sort((a, b) {
      final timeDiff = a.timestamp.compareTo(b.timestamp);
      if (timeDiff != 0) return timeDiff;

      /// FINAL SAFETY TIE-BREAKER
      return a.entityId.compareTo(b.entityId);
    });

    return resolved;
  }
}