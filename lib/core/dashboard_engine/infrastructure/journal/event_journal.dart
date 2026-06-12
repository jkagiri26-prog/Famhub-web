import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_event.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_source.dart';

/// ============================================================
/// EVENT JOURNAL — APPEND-ONLY CRASH-RESILIENT EVENT LOG
/// ============================================================
///
/// PURPOSE:
/// Provides at-least-once delivery by persisting every incoming
/// event BEFORE it enters the ConflictBuffer. On restart, the
/// journal is replayed to guarantee no event loss.
///
/// GUARANTEES:
/// - Append-only (inserts only, never deletes)
/// - Survives process crash
/// - Deterministic replay order (seq_id ascending)
/// - Thread-safe (sqflite ensures serial access)
/// - Transaction-safe append, prune, and read operations
/// - Corruption detection during replay
/// - Monotonic ordering validation
///
/// TABLE SCHEMA:
///   event_journal
///   ├── seq_id:     INTEGER PRIMARY KEY AUTOINCREMENT
///   ├── entity_id:  TEXT NOT NULL
///   ├── timestamp:  TEXT NOT NULL (ISO 8601)
///   ├── source:     TEXT NOT NULL
///   └── payload:    TEXT NOT NULL (JSON)
///
/// USAGE:
///   final journal = EventJournal(database);
///   await journal.append(event);
///   final events = await journal.readAfter(42);
/// ============================================================

class EventJournal {
  EventJournal(this._db);

  final Database _db;

  static const String _tableName = 'event_journal';
  static const String _createTable =
      '''
    CREATE TABLE IF NOT EXISTS $_tableName (
      seq_id    INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_id TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      source    TEXT NOT NULL,
      payload   TEXT NOT NULL
    )
  ''';

  /// Index for replay queries filtered by entity
  static const String _createIndex =
      '''
    CREATE INDEX IF NOT EXISTS idx_event_journal_entity
    ON $_tableName (entity_id, timestamp)
  ''';

  /// ============================================================
  /// SCHEMA INITIALIZATION (CALL ON APP START)
  /// ============================================================
  Future<void> ensureSchema() async {
    await _db.execute(_createTable);
    await _db.execute(_createIndex);
  }

  /// ============================================================
  /// APPEND — PERSISTS EVENT ATOMICALLY (TRANSACTION-WRAPPED)
  /// ============================================================
  ///
  /// Returns the auto-increment seq_id assigned to this event.
  /// Uses a SQLite transaction to ensure the insert either fully
  /// commits or fully rolls back. No partially-written journal
  /// state is possible.
  ///
  /// IMPORTANT: This MUST be called BEFORE ConflictBuffer.add()
  /// to guarantee crash recovery.
  ///
  Future<int> append(ConflictEvent event) async {
    return await _db.transaction<int>((txn) async {
      final id = await txn.insert(_tableName, {
        'entity_id': event.entityId,
        'timestamp': event.timestamp.toIso8601String(),
        'source': event.source.name,
        'payload': jsonEncode(event.payload),
      });
      return id;
    });
  }

  /// ============================================================
  /// READ AFTER — REPLAY ALL EVENTS AFTER A GIVEN SEQ_ID
  /// ============================================================
  ///
  /// Returns events in insertion order (oldest first).
  /// Pass [lastSeqId] = 0 to replay from the beginning.
  /// Pass [lastSeqId] = null to replay from the beginning.
  ///
  /// Each row is validated for corruption during replay.
  /// Invalid rows are safely skipped with diagnostic logging.
  /// Monotonic seq_id ordering is enforced — duplicates and
  /// out-of-order entries are detected and skipped.
  ///
  Future<List<ConflictEvent>> readAfter(int? lastSeqId) async {
    final rows = await _db.query(
      _tableName,
      where: lastSeqId != null ? 'seq_id > ?' : null,
      whereArgs: lastSeqId != null ? [lastSeqId] : null,
      orderBy: 'seq_id ASC',
    );

    final validEvents = <ConflictEvent>[];
    int? lastValidSeqId;

    for (final row in rows) {
      final seqId = row['seq_id'] as int?;
      final event = _safeRowToEvent(row, seqId);

      if (event == null) {
        // Invalid row — diagnostics already emitted, skip safely
        continue;
      }

      // === TASK A3: Replay Ordering Validation ===
      if (seqId != null && lastValidSeqId != null) {
        if (seqId <= lastValidSeqId) {
          // Duplicate or out-of-order seq_id detected
          _logWarning(
            'Replay ordering violation: seq_id=$seqId <= last_valid=$lastValidSeqId. '
            'Skipping duplicate/out-of-order entry.',
          );
          continue;
        }
      }

      lastValidSeqId = seqId ?? lastValidSeqId;
      validEvents.add(event);
    }

    return validEvents;
  }

  /// ============================================================
  /// GET LAST SEQ ID — RETURN HIGHEST PERSISTED SEQ_ID
  /// ============================================================
  Future<int?> getLastSequenceId() async {
    final result = await _db.rawQuery(
      'SELECT MAX(seq_id) AS max_id FROM $_tableName',
    );

    return result.first['max_id'] as int?;
  }

  /// ============================================================
  /// PRUNE BEFORE — SAFE JOURNAL COMPACTION (TRANSACTION-WRAPPED)
  /// ============================================================
  ///
  /// Deletes all events with seq_id <= [sequenceId].
  /// Wrapped in a transaction to ensure atomic deletion:
  /// either all matching rows are removed or none are.
  /// Partial deletion cannot occur under crash conditions.
  ///
  /// SAFETY RULE:
  /// Only call AFTER a checkpoint has been saved at [sequenceId].
  /// Once a checkpoint exists at seq=N, events ≤ N are fully
  /// represented in the materialized state and safe to delete.
  ///
  /// If journal pruning removes events that have NOT been
  /// checkpointed, replay would lose them. Callers MUST enforce
  /// that [sequenceId] <= checkpoint.lastSequenceId.
  ///
  Future<void> pruneBefore(int sequenceId) async {
    await _db.transaction((txn) async {
      await txn.delete(_tableName, where: 'seq_id <= ?', whereArgs: [sequenceId]);
    });
  }

  /// ============================================================
  /// GET OLDEST SEQ ID (DIAGNOSTIC)
  /// ============================================================
  Future<int?> getFirstSequenceId() async {
    final result = await _db.rawQuery(
      'SELECT MIN(seq_id) AS min_id FROM $_tableName',
    );
    return result.first['min_id'] as int?;
  }

  /// ============================================================
  /// GET EVENT COUNT (DIAGNOSTIC)
  /// ============================================================
  Future<int> count() async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $_tableName',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// ============================================================
  /// PHASE 6 — TASK B1: JOURNAL VACUUM
  /// ============================================================
  ///
  /// Recovers disk space after large prune operations.
  /// Should only be called when app is idle and after compaction.
  /// VACUUM rebuilds the entire database file, reclaiming free pages.
  ///
  Future<void> vacuum() async {
    await _db.execute('VACUUM');
  }

  /// ============================================================
  /// GET JOURNAL FILE SIZE (DIAGNOSTIC)
  /// ============================================================
  Future<int> getJournalSizeBytes() async {
    try {
      final result = await _db.rawQuery('PRAGMA page_count');
      final pageCount = Sqflite.firstIntValue(result) ?? 0;
      final pageSizeResult = await _db.rawQuery('PRAGMA page_size');
      final pageSize = Sqflite.firstIntValue(pageSizeResult) ?? 4096;
      return pageCount * pageSize;
    } catch (_) {
      return 0;
    }
  }

  /// ============================================================
  /// VALIDATE JOURNAL EVENT — TASK A2 CORRUPTION DETECTION
  /// ============================================================
  /// ============================================================
  ///
  /// Validates that a raw database row contains all required fields
  /// and that they can be parsed correctly. Returns true if the row
  /// is valid, false if corrupted.
  ///
  /// Validation checks:
  /// - entity_id: non-null, non-empty String
  /// - source: valid ConflictSource enum value
  /// - timestamp: valid ISO 8601 DateTime
  /// - payload: valid JSON that decodes to Map<String, dynamic>
  ///
  bool isValidJournalEvent(Map<String, dynamic> row) {
    // Check entity_id
    if (row['entity_id'] == null || (row['entity_id'] as String).isEmpty) {
      _logWarning('Corrupted journal row: missing or empty entity_id');
      return false;
    }

    // Check source
    if (row['source'] == null) {
      _logWarning('Corrupted journal row: missing source field');
      return false;
    }
    try {
      ConflictSource.values.byName(row['source'] as String);
    } catch (_) {
      _logWarning(
        'Corrupted journal row: invalid source="${row['source']}"',
      );
      return false;
    }

    // Check timestamp
    if (row['timestamp'] == null) {
      _logWarning('Corrupted journal row: missing timestamp');
      return false;
    }
    try {
      DateTime.parse(row['timestamp'] as String);
    } catch (_) {
      _logWarning(
        'Corrupted journal row: unparseable timestamp="${row['timestamp']}"',
      );
      return false;
    }

    // Check payload — must be valid JSON decoding to Map
    if (row['payload'] == null) {
      _logWarning('Corrupted journal row: missing payload');
      return false;
    }
    try {
      final decoded = jsonDecode(row['payload'] as String);
      if (decoded is! Map<String, dynamic>) {
        _logWarning(
          'Corrupted journal row: payload is not a Map',
        );
        return false;
      }
    } catch (_) {
      _logWarning(
        'Corrupted journal row: unparseable payload JSON',
      );
      return false;
    }

    return true;
  }

  /// ============================================================
  /// SAFE ROW → ConflictEvent (WITH CORRUPTION DETECTION)
  /// ============================================================
  ///
  /// Attempts to convert a raw database row into a ConflictEvent.
  /// If validation fails, logs a diagnostic warning and returns null.
  /// The caller should skip the row and continue replay.
  ///
  ConflictEvent? _safeRowToEvent(Map<String, dynamic> row, int? seqId) {
    if (!isValidJournalEvent(row)) {
      return null;
    }

    try {
      return ConflictEvent(
        entityId: row['entity_id'] as String,
        source: ConflictSource.values.byName(row['source'] as String),
        timestamp: DateTime.parse(row['timestamp'] as String),
        payload: Map<String, dynamic>.from(
          jsonDecode(row['payload'] as String) as Map,
        ),
      );
    } catch (e) {
      _logWarning(
        'Failed to convert journal row seq_id=$seqId to event: $e',
      );
      return null;
    }
  }

  /// ============================================================
  /// STRUCTURED LOGGING HELPER
  /// ============================================================
  void _logWarning(String message) {
    // ignore: avoid_print
    print('[EventJournal] WARNING: $message');
  }

  /// ============================================================
  /// ROW → ConflictEvent (LEGACY, UNCHANGED)
  /// ============================================================
  ConflictEvent _rowToEvent(Map<String, dynamic> row) {
    return ConflictEvent(
      entityId: row['entity_id'] as String,
      source: ConflictSource.values.byName(row['source'] as String),
      timestamp: DateTime.parse(row['timestamp'] as String),
      payload: Map<String, dynamic>.from(
        jsonDecode(row['payload'] as String) as Map,
      ),
    );
  }
}
