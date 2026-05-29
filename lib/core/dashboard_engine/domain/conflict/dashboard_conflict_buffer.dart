import 'dashboard_conflict_event.dart';
import 'dashboard_conflict_resolver.dart';

/// ============================================================
/// CONFLICT BUFFER (HARDENED ATOMIC VERSION v2)
/// ============================================================
///
/// GUARANTEES:
/// - No event loss on resolver failure
/// - Strict FIFO + LRU hybrid correctness
/// - Safe snapshot isolation
/// - No mutation during resolution
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

  /// ============================================================
  /// INGEST (LATEST WINS PER ENTITY)
  /// ============================================================
  void add(ConflictEvent event) {
    final entityId = event.entityId;

    // overwrite or insert
    _events[entityId] = event;

    // maintain FIFO ordering safely
    _order.remove(entityId);
    _order.add(entityId);

    // enforce capacity
    if (_events.length > maxBufferSize) {
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
      /// snapshot FIRST (no mutation risk)
      final snapshot = <ConflictEvent>[];

      for (final id in List<String>.from(_order)) {
        final event = _events[id];
        if (event != null) {
          snapshot.add(event);
        }
      }

      /// IMPORTANT:
      /// DO NOT clear yet — only clear AFTER successful resolve
      final resolved = _resolver.resolveBatch(snapshot);

      // only clear AFTER success
      clear();

      return resolved;
    } catch (_) {
      // IMPORTANT: never lose events on failure
      // keep buffer intact for retry
      return const [];
    } finally {
      _isResolving = false;
    }
  }

  /// ============================================================
  /// EVICTION (FIFO SAFE)
  /// ============================================================
  void _evictOldest() {
    if (_order.isEmpty) return;

    final oldest = _order.removeAt(0);
    _events.remove(oldest);
  }

  /// ============================================================
  /// RESET
  /// ============================================================
  void clear() {
    _events.clear();
    _order.clear();
  }

  /// ============================================================
  /// DIAGNOSTICS
  /// ============================================================
  int get length => _events.length;

  bool get isEmpty => _events.isEmpty;

  bool get isNotEmpty => _events.isNotEmpty;

  bool get isNearCapacity => _events.length >= (maxBufferSize * 0.8);

  double get utilization => _events.length / maxBufferSize;
}