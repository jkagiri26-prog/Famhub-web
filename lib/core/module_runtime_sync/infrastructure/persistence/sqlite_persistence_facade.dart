import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_event.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_source.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';
import 'package:famhub_app/core/module_runtime_sync/infrastructure/persistence/persistence_store.dart';

/// ============================================================
/// SQLITE PERSISTENCE FACADE — Native platforms (Mobile/Desktop)
/// ============================================================
///
/// Wraps the existing EventJournal + RuntimeCheckpointStore into
/// the PersistenceStore interface. Preserves all crash-resilience
/// guarantees (transactional writes, replay, compaction).
/// ============================================================
class SqlitePersistenceFacade implements PersistenceStore {
  Database? _journalDb;
  Database? _checkpointDb;
  bool _initialized = false;

  static const String _journalTable = 'event_journal';
  static const String _checkpointTable = 'runtime_checkpoints';

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    final dbPath = await getDatabasesPath();
    final journalPath = join(dbPath, 'dashboard_event_journal.db');
    final checkpointPath = join(dbPath, 'dashboard_checkpoint.db');

    _journalDb = await openDatabase(journalPath, version: 1,
        onCreate: (db, version) async {
      await db.execute('''
CREATE TABLE IF NOT EXISTS $_journalTable (
  seq_id    INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_id TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  source    TEXT NOT NULL,
  payload   TEXT NOT NULL
)
''');
      await db.execute('''
CREATE INDEX IF NOT EXISTS idx_event_journal_entity
ON $_journalTable (entity_id, timestamp)
''');
    });

    _checkpointDb = await openDatabase(checkpointPath, version: 1,
        onCreate: (db, version) async {
      await db.execute('''
CREATE TABLE IF NOT EXISTS $_checkpointTable (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  schema_version   INTEGER NOT NULL,
  last_sequence_id INTEGER NOT NULL,
  created_at       TEXT    NOT NULL,
  payload          TEXT    NOT NULL
)
''');
    });

    _initialized = true;
  }

  @override
  Future<int> appendEvent(ConflictEvent event) async {
    final db = _journalDb;
    if (db == null) throw StateError('PersistenceStore not initialized');

    return await db.transaction<int>((txn) async {
      return await txn.insert(_journalTable, {
        'entity_id': event.entityId,
        'timestamp': event.timestamp.toIso8601String(),
        'source': event.source.name,
        'payload': jsonEncode(event.payload),
      });
    });
  }

  @override
  Future<List<ConflictEvent>> readEventsAfter(int seqId) async {
    final db = _journalDb;
    if (db == null) throw StateError('PersistenceStore not initialized');

    final rows = await db.query(
      _journalTable,
      where: 'seq_id > ?',
      whereArgs: [seqId],
      orderBy: 'seq_id ASC',
    );

    return rows.map((row) {
      return ConflictEvent(
        entityId: row['entity_id'] as String,
        source: ConflictSource.values.byName(row['source'] as String),
        timestamp: DateTime.parse(row['timestamp'] as String),
        payload: Map<String, dynamic>.from(
          jsonDecode(row['payload'] as String) as Map,
        ),
      );
    }).toList();
  }

  @override
  Future<int?> getLastEventSequenceId() async {
    final db = _journalDb;
    if (db == null) throw StateError('PersistenceStore not initialized');

    final result = await db.rawQuery(
      'SELECT MAX(seq_id) AS max_id FROM $_journalTable',
    );
    return result.first['max_id'] as int?;
  }

  @override
  Future<void> pruneEventsBefore(int sequenceId) async {
    final db = _journalDb;
    if (db == null) throw StateError('PersistenceStore not initialized');

    await db.transaction((txn) async {
      await txn.delete(
        _journalTable,
        where: 'seq_id <= ?',
        whereArgs: [sequenceId],
      );
    });
  }

  @override
  Future<int> getEventCount() async {
    final db = _journalDb;
    if (db == null) throw StateError('PersistenceStore not initialized');

    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $_journalTable',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> saveCheckpoint({
    required int lastSequenceId,
    required ModuleRuntimeState moduleState,
  }) async {
    final db = _checkpointDb;
    if (db == null) throw StateError('PersistenceStore not initialized');

    await db.transaction((txn) async {
      await txn.insert(_checkpointTable, {
        'schema_version': 1,
        'last_sequence_id': lastSequenceId,
        'created_at': DateTime.now().toIso8601String(),
        'payload': jsonEncode({
          'lastSequenceId': lastSequenceId,
          'activeModules': moduleState.activeModules.toList(),
          'disabledModules': moduleState.disabledModules.toList(),
          'maintenanceModules': moduleState.maintenanceModules.toList(),
          'lastSyncedAt': moduleState.lastSyncedAt?.toIso8601String(),
        }),
      });

      // Retain only latest 2 checkpoints
      final allIds = await txn.query(
        _checkpointTable,
        columns: ['id'],
        orderBy: 'id DESC',
      );
      if (allIds.length > 2) {
        final idsToKeep = allIds.take(2).map((r) => r['id'] as int).toList();
        await txn.delete(
          _checkpointTable,
          where: 'id NOT IN (${idsToKeep.map((_) => '?').join(',')})',
          whereArgs: idsToKeep,
        );
      }
    });
  }

  @override
  Future<ModuleRuntimeState?> loadLatestCheckpoint() async {
    final db = _checkpointDb;
    if (db == null) throw StateError('PersistenceStore not initialized');

    final rows = await db.query(
      _checkpointTable,
      orderBy: 'id DESC',
      limit: 1,
    );

    if (rows.isEmpty) return null;

    try {
      final payload =
          jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;

      return ModuleRuntimeState(
        activeModules:
            (payload['activeModules'] as List?)?.map((e) => e.toString()).toSet() ??
                <String>{},
        disabledModules:
            (payload['disabledModules'] as List?)?.map((e) => e.toString()).toSet() ??
                <String>{},
        maintenanceModules:
            (payload['maintenanceModules'] as List?)?.map((e) => e.toString()).toSet() ??
                <String>{},
        lastSyncedAt: payload['lastSyncedAt'] != null
            ? DateTime.parse(payload['lastSyncedAt'] as String)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clear() async {
    if (_journalDb != null) {
      await _journalDb!.delete(_journalTable);
    }
    if (_checkpointDb != null) {
      await _checkpointDb!.delete(_checkpointTable);
    }
  }

  @override
  Future<void> dispose() async {
    await _journalDb?.close();
    await _checkpointDb?.close();
    _journalDb = null;
    _checkpointDb = null;
    _initialized = false;
  }
}
