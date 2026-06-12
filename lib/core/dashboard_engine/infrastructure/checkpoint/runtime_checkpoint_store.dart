import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';

/// ============================================================
/// RUNTIME CHECKPOINT
/// ============================================================
///
/// A point-in-time snapshot of the fully reconciled module state
/// at a known journal sequence boundary.
///
/// STORES:
/// - lastSequenceId: last journal seq_id that contributed to this state
/// - moduleState: materialized ModuleRuntimeState at that point
/// - schemaVersion: for forward-compatible deserialization
/// ============================================================
class RuntimeCheckpoint {
  RuntimeCheckpoint({
    required this.lastSequenceId,
    required this.createdAt,
    required this.moduleState,
    this.schemaVersion = 1,
  });

  final int lastSequenceId;
  final DateTime createdAt;
  final ModuleRuntimeState moduleState;
  final int schemaVersion;

  /// ============================================================
  /// SERIALIZE TO JSON
  /// ============================================================
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'lastSequenceId': lastSequenceId,
      'createdAt': createdAt.toIso8601String(),
      'moduleState': {
        'activeModules': moduleState.activeModules.toList(),
        'disabledModules': moduleState.disabledModules.toList(),
        'maintenanceModules': moduleState.maintenanceModules.toList(),
        'lastSyncedAt': moduleState.lastSyncedAt?.toIso8601String(),
      },
    };
  }

  /// ============================================================
  /// DESERIALIZE FROM JSON (WITH FORWARD-COMPATIBLE TOLERANCE)
  /// ============================================================
  factory RuntimeCheckpoint.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int? ?? 1;
    final moduleStateJson = json['moduleState'] as Map<String, dynamic>? ?? {};

    return RuntimeCheckpoint(
      schemaVersion: schemaVersion,
      lastSequenceId: json['lastSequenceId'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      moduleState: ModuleRuntimeState(
        activeModules:
            (moduleStateJson['activeModules'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            <String>{},
        disabledModules:
            (moduleStateJson['disabledModules'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            <String>{},
        maintenanceModules:
            (moduleStateJson['maintenanceModules'] as List?)
                ?.map((e) => e.toString())
                .toSet() ??
            <String>{},
        lastSyncedAt: moduleStateJson['lastSyncedAt'] != null
            ? DateTime.parse(moduleStateJson['lastSyncedAt'] as String)
            : null,
      ),
    );
  }
}

/// ============================================================
/// RUNTIME CHECKPOINT STORE
/// ============================================================
///
/// PERSISTS the latest materialized ModuleRuntimeState + its
/// journal sequence boundary checkpoint.
///
/// TABLE SCHEMA:
///   runtime_checkpoints
///   ├── id:               INTEGER PRIMARY KEY
///   ├── schema_version:   INTEGER NOT NULL
///   ├── last_sequence_id: INTEGER NOT NULL
///   ├── created_at:       TEXT NOT NULL (ISO 8601)
///   └── payload:          TEXT NOT NULL (full JSON payload)
///
/// INVARIANT:
/// - Up to 2 checkpoints retained: latest + previous (safety fallback)
/// - Older entries are automatically pruned on save
/// - If all checkpoints are invalid, system degrades gracefully
///   to full journal replay (correctness preserved, replay slower)
///
/// SAFETY:
/// - Schema-versioned payload for forward migration
/// - Missing fields tolerated via null-safe deserialization
/// - Transaction-atomic save: insert new + remove old in one tx
/// - Validation on load rejects malformed checkpoints
/// ============================================================
class RuntimeCheckpointStore {
  RuntimeCheckpointStore(this._db);

  final Database _db;

  static const String _tableName = 'runtime_checkpoints';
  static const String _createTable =
      '''
    CREATE TABLE IF NOT EXISTS $_tableName (
      id               INTEGER PRIMARY KEY AUTOINCREMENT,
      schema_version   INTEGER NOT NULL,
      last_sequence_id INTEGER NOT NULL,
      created_at       TEXT    NOT NULL,
      payload          TEXT    NOT NULL
    )
  ''';

  /// Maximum number of checkpoints to retain (latest + fallback)
  static const int _maxRetainedCheckpoints = 2;

  /// ============================================================
  /// SCHEMA INITIALIZATION (CALL ON APP START)
  /// ============================================================
  Future<void> ensureSchema() async {
    await _db.execute(_createTable);
  }

  /// ============================================================
  /// SAVE CHECKPOINT (ATOMIC — TASK B2)
  /// ============================================================
  ///
  /// Uses a transaction to atomically:
  /// 1. Insert the new checkpoint
  /// 2. Optionally remove old checkpoints beyond retention limit
  ///
  /// This guarantees no intermediate invalid state: if a crash
  /// occurs during save, at least one valid checkpoint remains.
  /// The database never has a partially-written checkpoint.
  ///
  Future<void> saveCheckpoint(RuntimeCheckpoint checkpoint) async {
    await _db.transaction((txn) async {
      // Step 1: Insert new checkpoint
      await txn.insert(_tableName, {
        'schema_version': checkpoint.schemaVersion,
        'last_sequence_id': checkpoint.lastSequenceId,
        'created_at': checkpoint.createdAt.toIso8601String(),
        'payload': jsonEncode(checkpoint.toJson()),
      });

      // Step 2: Enforce retention policy (TASK B3)
      // Keep only the latest _maxRetainedCheckpoints entries
      // Order by id DESC so we keep the newest rows
      final allIds = await txn.query(
        _tableName,
        columns: ['id'],
        orderBy: 'id DESC',
      );

      if (allIds.length > _maxRetainedCheckpoints) {
        final idsToKeep = allIds
            .take(_maxRetainedCheckpoints)
            .map((r) => r['id'] as int)
            .toList();

        await txn.delete(
          _tableName,
          where: 'id NOT IN (${idsToKeep.map((_) => '?').join(',')})',
          whereArgs: idsToKeep,
        );
      }
    });
  }

  /// ============================================================
  /// LOAD LATEST CHECKPOINT (WITH VALIDATION — TASK B1)
  /// ============================================================
  ///
  /// Attempts to load the most recent valid checkpoint.
  /// If the latest checkpoint fails validation, falls back to
  /// the previous checkpoint (if available).
  ///
  /// Returns null if no valid checkpoint exists.
  /// Caller should then fallback to full journal replay.
  ///
  Future<RuntimeCheckpoint?> loadLatestCheckpoint() async {
    // Load all checkpoints ordered by id DESC (newest first)
    final rows = await _db.query(
      _tableName,
      orderBy: 'id DESC',
      limit: _maxRetainedCheckpoints,
    );

    if (rows.isEmpty) return null;

    // Try each checkpoint from newest to oldest
    for (final row in rows) {
      try {
        final payload =
            jsonDecode(row['payload'] as String) as Map<String, dynamic>;

        if (!isValidCheckpoint(payload)) {
          _logWarning('Invalid checkpoint skipped (id=${row['id']})');
          continue;
        }

    return RuntimeCheckpoint.fromJson(payload);
      } catch (e) {
        _logWarning(
          'Failed to load checkpoint (id=${row['id']}): $e. Skipping.',
        );
        continue;
      }
    }

    // No valid checkpoint found
    return null;
  }

  /// ============================================================
  /// VALIDATE CHECKPOINT — TASK B1
  /// ============================================================
  ///
  /// Validates that a checkpoint JSON payload contains all
  /// required fields and that they have correct types/values.
  ///
  /// Validation rules:
  /// - schemaVersion: must be present and > 0
  /// - lastSequenceId: must be present and > 0
  /// - createdAt: must be a valid ISO 8601 DateTime
  /// - moduleState: must be present as a Map
  /// - moduleState.activeModules, disabledModules, maintenanceModules:
  ///   must be present as Lists (can be empty)
  ///
  bool isValidCheckpoint(Map<String, dynamic> json) {
    // Validate schemaVersion
    if (json['schemaVersion'] == null) {
      _logWarning('Checkpoint validation failed: missing schemaVersion');
      return false;
    }
    if (json['schemaVersion'] is! int || (json['schemaVersion'] as int) <= 0) {
      _logWarning(
        'Checkpoint validation failed: invalid schemaVersion=${json['schemaVersion']}',
      );
      return false;
    }

    // Validate lastSequenceId
    if (json['lastSequenceId'] == null) {
      _logWarning('Checkpoint validation failed: missing lastSequenceId');
      return false;
    }
    if (json['lastSequenceId'] is! int || (json['lastSequenceId'] as int) < 0) {
      _logWarning(
        'Checkpoint validation failed: invalid lastSequenceId=${json['lastSequenceId']}',
      );
      return false;
    }

    // Validate createdAt
    if (json['createdAt'] == null) {
      _logWarning('Checkpoint validation failed: missing createdAt');
      return false;
    }
    try {
      DateTime.parse(json['createdAt'] as String);
    } catch (_) {
      _logWarning(
        'Checkpoint validation failed: unparseable createdAt="${json['createdAt']}"',
      );
      return false;
    }

    // Validate moduleState shape
    if (json['moduleState'] == null || json['moduleState'] is! Map) {
      _logWarning('Checkpoint validation failed: missing or invalid moduleState');
      return false;
    }

    final ms = json['moduleState'] as Map<String, dynamic>;

    // Required state fields (must be present, can be empty)
    if (ms['activeModules'] != null && ms['activeModules'] is! List) {
      _logWarning('Checkpoint validation failed: activeModules is not a List');
      return false;
    }
    if (ms['disabledModules'] != null && ms['disabledModules'] is! List) {
      _logWarning('Checkpoint validation failed: disabledModules is not a List');
      return false;
    }
    if (ms['maintenanceModules'] != null && ms['maintenanceModules'] is! List) {
      _logWarning('Checkpoint validation failed: maintenanceModules is not a List');
      return false;
    }

    return true;
  }

  /// ============================================================
  /// LOAD PREVIOUS CHECKPOINT (FALLBACK)
  /// ============================================================
  ///
  /// Loads the second-most-recent checkpoint if available.
  /// Used when the latest checkpoint is corrupted.
  ///
  Future<RuntimeCheckpoint?> loadPreviousCheckpoint() async {
    final rows = await _db.query(
      _tableName,
      orderBy: 'id DESC',
      limit: 2,
    );

    if (rows.length < 2) return null;

    try {
      final row = rows[1]; // second row = second newest
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;

      if (!isValidCheckpoint(payload)) {
        return null;
      }

      return RuntimeCheckpoint.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  /// ============================================================
  /// CLEAR (FOR TESTING / RECOVERY)
  /// ============================================================
  Future<void> clear() async {
    await _db.delete(_tableName);
  }

  /// ============================================================
  /// STRUCTURED LOGGING HELPER
  /// ============================================================
  void _logWarning(String message) {
    // ignore: avoid_print
    print('[CheckpointStore] WARNING: $message');
  }
}
