import 'dart:convert';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_event.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_source.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';
import 'package:famhub_app/core/module_runtime_sync/infrastructure/persistence/persistence_store.dart';

/// ============================================================
/// MEMORY PERSISTENCE STORE — Web-compatible fallback
/// ============================================================
///
/// In-memory implementation that preserves all engine behavior
/// without SQLite dependency. Data is volatile (per session).
/// Used on Flutter Web where sqflite is unavailable.
///
/// Architecture: List-based event journal + Map-based checkpoint store
/// All operations are synchronous (no I/O latency).
/// ============================================================
class MemoryPersistenceStore implements PersistenceStore {
  int _nextSeqId = 1;
  final List<_JournalEntry> _journal = [];
  ModuleRuntimeState? _latestCheckpoint;
  int _checkpointSequenceId = 0;

  @override
  Future<void> initialize() async {
    // Nothing to initialize for memory store
  }

  @override
  Future<int> appendEvent(ConflictEvent event) async {
    final seqId = _nextSeqId++;
    _journal.add(_JournalEntry(
      seqId: seqId,
      entityId: event.entityId,
      timestamp: event.timestamp,
      source: event.source.name,
      payload: event.payload,
    ));
    return seqId;
  }

  @override
  Future<List<ConflictEvent>> readEventsAfter(int seqId) async {
    return _journal
        .where((entry) => entry.seqId > seqId)
        .map((entry) => ConflictEvent(
              entityId: entry.entityId,
              source: ConflictSource.values.byName(entry.source),
              timestamp: entry.timestamp,
              payload: Map<String, dynamic>.from(entry.payload),
            ))
        .toList();
  }

  @override
  Future<int?> getLastEventSequenceId() async {
    if (_journal.isEmpty) return null;
    return _journal.last.seqId;
  }

  @override
  Future<void> pruneEventsBefore(int sequenceId) async {
    _journal.removeWhere((entry) => entry.seqId <= sequenceId);
  }

  @override
  Future<int> getEventCount() async {
    return _journal.length;
  }

  @override
  Future<void> saveCheckpoint({
    required int lastSequenceId,
    required ModuleRuntimeState moduleState,
  }) async {
    _checkpointSequenceId = lastSequenceId;
    _latestCheckpoint = moduleState;
  }

  @override
  Future<ModuleRuntimeState?> loadLatestCheckpoint() async {
    return _latestCheckpoint;
  }

  @override
  Future<void> clear() async {
    _journal.clear();
    _latestCheckpoint = null;
    _checkpointSequenceId = 0;
    _nextSeqId = 1;
  }

  @override
  Future<void> dispose() async {
    clear();
  }
}

class _JournalEntry {
  final int seqId;
  final String entityId;
  final DateTime timestamp;
  final String source;
  final Map<String, dynamic> payload;

  _JournalEntry({
    required this.seqId,
    required this.entityId,
    required this.timestamp,
    required this.source,
    required this.payload,
  });
}
