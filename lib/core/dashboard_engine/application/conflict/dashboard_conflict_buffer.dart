// lib/core/dashboard_engine/application/conflict/dashboard_conflict_buffer.dart

import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_event.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_resolver.dart';

/// ============================================================
/// CONFLICT BUFFER (v3 — WITH CAPACITY CONTROLS & OVERFLOW DIAGNOSTICS)
/// ============================================================
///
/// GUARANTEES:
/// - No event loss on resolver failure
/// - Strict FIFO + LRU hybrid correctness
/// - Safe snapshot isolation
/// - No mutation during resolution
/// - Memory bounded via eviction + capacity diagnostics
/// - Overflow detectable via diagnostic fields
///
/// PHASE 6 — TASK A3:
/// - Overflow diagnostics (overflowCount, totalDropped)
/// - Capacity health check
/// ============================================================

class ConflictBuffer {
  ConflictBuffer(
    this._resolver, {
    this.maxBufferSize = 500,
  });

  final ConflictResolver _resolver;

  final Map<String, ConflictEvent> _events = {};
  final List<String> _order = [];

  final int maxBufferSize;

  // Snapshot lock to prevent concurrent drain corruption
  bool _isResolving = false;

  // Phase 6 — TASK A3: Overflow diagnostics
  int _overflowCount = 0;
  int _totalDroppedEvents = 0;

    /// ============================================================
  /// INGEST (LATEST WINS PER ENTITY WITH STALENESS GUARD)
  /// ============================================================
  void add(ConflictEvent event) {
    final entityId = event.entityId;
    final existing = _events[entityId];

    // ==========================================================
    // STALENESS GUARD: reject events older than current state
    // ==========================================================
    if (existing != null) {
      if (event.timestamp.isBefore(existing.timestamp)) {
        return;
      }

      // If timestamps are equal, prefer higher sequence if available
      if (event.timestamp.isAtSameMomentAs(existing.timestamp)) {
        final existingSeq = existing.sequenceId ?? '';
        final incomingSeq = event.sequenceId ?? '';
        if (incomingSeq.compareTo(existingSeq) < 0) {
          return;
        }
      }
    }

    // overwrite or insert
    _events[entityId] = event;

    // maintain FIFO ordering safely
    _order.remove(entityId);
    _order.add(entityId);

        // enforce capacity (TASK A3)
    if (_events.length > maxBufferSize) {
      _overflowCount++;
      _evictOldest();
    }
  }

  /// ============================================================
  /// ATOMIC RESOLVE (SAFE AGAINST FAILURE + RE-ENTRY)
  /// ============================================================
  List<ConflictEvent> resolveAll() {
    if (_events.isEmpty || _isResolving) return const [];

    _isResolving = true;

    try {
      final snapshot = <ConflictEvent>[];

      for (final id in List<String>.from(_order)) {
        final event = _events[id];
        if (event != null) {
          snapshot.add(event);
        }
      }

      final resolved = _resolver.resolveBatch(snapshot);

      // only clear AFTER success
      clear();

      return resolved;
    } catch (_) {
      // keep buffer intact for retry
      return const [];
    } finally {
      _isResolving = false;
    }
  }

    /// ============================================================
  /// EVICTION (FIFO SAFE) — TASK A3
  /// ============================================================
  void _evictOldest() {
    if (_order.isEmpty) return;

    final oldest = _order.removeAt(0);
    _events.remove(oldest);
    _totalDroppedEvents++;
  }

  /// ============================================================
  /// RESET
  /// ============================================================
  void clear() {
    _events.clear();
    _order.clear();
  }

    /// ============================================================
  /// DIAGNOSTICS — TASK A3 (INCLUDING OVERFLOW)
  /// ============================================================
  int get length => _events.length;

  bool get isEmpty => _events.isEmpty;

  bool get isNotEmpty => _events.isNotEmpty;

  bool get isNearCapacity => _events.length >= (maxBufferSize * 0.8);

  double get utilization => _events.length / maxBufferSize;

  /// Number of times buffer overflowed
  int get overflowCount => _overflowCount;

  /// Total events dropped due to capacity limits
  int get totalDroppedEvents => _totalDroppedEvents;

  /// Reset overflow diagnostics (for periodic health checks)
  void resetDiagnostics() {
    _overflowCount = 0;
    _totalDroppedEvents = 0;
  }

  /// Returns all entities currently buffered (for diagnostics)
  List<String> get entityIds => List<String>.from(_order);
}