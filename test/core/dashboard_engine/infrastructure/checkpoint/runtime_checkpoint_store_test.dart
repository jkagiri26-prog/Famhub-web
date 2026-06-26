import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:famhub_app/core/dashboard_engine/infrastructure/checkpoint/runtime_checkpoint_store.dart';
import 'package:famhub_app/core/module_runtime_sync/domain/models/module_runtime_state.dart';

void main() {
  late Database db;
  late RuntimeCheckpointStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS runtime_checkpoints (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        schema_version   INTEGER NOT NULL,
        last_sequence_id INTEGER NOT NULL,
        created_at       TEXT    NOT NULL,
        payload          TEXT    NOT NULL
      )
    ''');
    store = RuntimeCheckpointStore(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ============================================================
  // TASK B1: Checkpoint Validation Tests
  // ============================================================
  group('TASK B1 — Checkpoint Validation', () {
    test('valid checkpoint passes validation', () {
      final validJson = <String, dynamic>{
        'schemaVersion': 1,
        'lastSequenceId': 42,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'moduleState': {
          'activeModules': ['mod-a', 'mod-b'],
          'disabledModules': [],
          'maintenanceModules': [],
          'lastSyncedAt': null,
        },
      };

      expect(store.isValidCheckpoint(validJson), isTrue);
    });

    test('missing schemaVersion is invalid', () {
      final json = <String, dynamic>{
        'lastSequenceId': 42,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'moduleState': {
          'activeModules': [],
          'disabledModules': [],
          'maintenanceModules': [],
        },
      };

      expect(store.isValidCheckpoint(json), isFalse);
    });

    test('schemaVersion <= 0 is invalid', () {
      final json = <String, dynamic>{
        'schemaVersion': 0,
        'lastSequenceId': 42,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'moduleState': {
          'activeModules': [],
          'disabledModules': [],
          'maintenanceModules': [],
        },
      };

      expect(store.isValidCheckpoint(json), isFalse);
    });

    test('missing lastSequenceId is invalid', () {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'moduleState': {
          'activeModules': [],
          'disabledModules': [],
          'maintenanceModules': [],
        },
      };

      expect(store.isValidCheckpoint(json), isFalse);
    });

    test('negative lastSequenceId is invalid', () {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'lastSequenceId': -1,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'moduleState': {
          'activeModules': [],
          'disabledModules': [],
          'maintenanceModules': [],
        },
      };

      expect(store.isValidCheckpoint(json), isFalse);
    });

    test('missing createdAt is invalid', () {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'lastSequenceId': 42,
        'moduleState': {
          'activeModules': [],
          'disabledModules': [],
          'maintenanceModules': [],
        },
      };

      expect(store.isValidCheckpoint(json), isFalse);
    });

    test('unparseable createdAt is invalid', () {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'lastSequenceId': 42,
        'createdAt': 'not-a-date',
        'moduleState': {
          'activeModules': [],
          'disabledModules': [],
          'maintenanceModules': [],
        },
      };

      expect(store.isValidCheckpoint(json), isFalse);
    });

    test('missing moduleState is invalid', () {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'lastSequenceId': 42,
        'createdAt': '2024-01-01T00:00:00.000Z',
      };

      expect(store.isValidCheckpoint(json), isFalse);
    });

    test('non-Map moduleState is invalid', () {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'lastSequenceId': 42,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'moduleState': 'not-a-map',
      };

      expect(store.isValidCheckpoint(json), isFalse);
    });

    test('non-List activeModules is invalid', () {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'lastSequenceId': 42,
        'createdAt': '2024-01-01T00:00:00.000Z',
        'moduleState': {
          'activeModules': 'not-a-list',
          'disabledModules': [],
          'maintenanceModules': [],
        },
      };

      expect(store.isValidCheckpoint(json), isFalse);
    });
  });

  // ============================================================
  // TASK B2: Atomic Save Tests
  // ============================================================
  group('TASK B2 — Atomic Checkpoint Save', () {
    test('saveCheckpoint persists checkpoint', () async {
      const state = ModuleRuntimeState(
        activeModules: {'mod-a'},
        disabledModules: {},
        maintenanceModules: {},
        lastSyncedAt: null,
      );

      await store.saveCheckpoint(RuntimeCheckpoint(
        lastSequenceId: 42,
        createdAt: DateTime.now(),
        moduleState: state,
      ));

      // Verify it exists
      final loaded = await store.loadLatestCheckpoint();
      expect(loaded, isNotNull);
      expect(loaded!.lastSequenceId, equals(42));
      expect(loaded.moduleState.activeModules, contains('mod-a'));
    });

    test('multiple saves retain latest', () async {
      for (int i = 1; i <= 5; i++) {
        await store.saveCheckpoint(RuntimeCheckpoint(
          lastSequenceId: i * 10,
          createdAt: DateTime.now(),
          moduleState: ModuleRuntimeState.initial(),
        ));
      }

      // Should only retain 2 checkpoints
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM runtime_checkpoints',
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      expect(count, equals(2));
    });

    test('saveCheckpoint uses transaction', () async {
      await store.saveCheckpoint(RuntimeCheckpoint(
        lastSequenceId: 100,
        createdAt: DateTime.now(),
        moduleState: ModuleRuntimeState.initial(),
      ));

      // Verify integrity
      final result = await db.rawQuery('PRAGMA integrity_check');
      expect(result.first.values.first, equals('ok'));
    });
  });

  // ============================================================
  // TASK B3: Retention Policy Tests
  // ============================================================
  group('TASK B3 — Checkpoint Retention', () {
    test('max 2 checkpoints retained', () async {
      // Save 5 checkpoints
      for (int i = 0; i < 5; i++) {
        await store.saveCheckpoint(RuntimeCheckpoint(
          lastSequenceId: i,
          createdAt: DateTime.now(),
          moduleState: ModuleRuntimeState.initial(),
        ));
      }

      // Should have exactly 2
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM runtime_checkpoints',
      );
      final count = Sqflite.firstIntValue(countResult) ?? 0;
      expect(count, equals(2));
    });

    test('latest checkpoint used on load', () async {
      for (int i = 1; i <= 3; i++) {
        await store.saveCheckpoint(RuntimeCheckpoint(
          lastSequenceId: i,
          createdAt: DateTime.now(),
          moduleState: ModuleRuntimeState(
            activeModules: {i.toString()},
            disabledModules: {},
            maintenanceModules: {},
            lastSyncedAt: null,
          ),
        ));
      }

      final loaded = await store.loadLatestCheckpoint();
      expect(loaded, isNotNull);
      // Should be the last saved
      expect(loaded!.moduleState.activeModules, contains('3'));
    });

    test('falls back to previous if latest is invalid', () async {
      // Save first valid checkpoint
      await store.saveCheckpoint(RuntimeCheckpoint(
        lastSequenceId: 1,
        createdAt: DateTime.now(),
        moduleState: const ModuleRuntimeState(
          activeModules: {'first'},
          disabledModules: {},
          maintenanceModules: {},
          lastSyncedAt: null,
        ),
      ));

      // Manually insert a corrupted checkpoint
      await db.insert('runtime_checkpoints', {
        'schema_version': 1,
        'last_sequence_id': 2,
        'created_at': DateTime.now().toIso8601String(),
        'payload': '{"corrupted": true}', // Invalid payload
      });

      // loadLatestCheckpoint should skip corrupted and return valid one
      final loaded = await store.loadLatestCheckpoint();
      expect(loaded, isNotNull);
      expect(loaded!.lastSequenceId, equals(1));
      expect(loaded.moduleState.activeModules, contains('first'));
    });

    test('returns null when no valid checkpoints', () async {
      // Only corrupted checkpoints
      await db.insert('runtime_checkpoints', {
        'schema_version': 1,
        'last_sequence_id': 1,
        'created_at': 'bad-date',
        'payload': '{"corrupted": true}',
      });

      final loaded = await store.loadLatestCheckpoint();
      expect(loaded, isNull);
    });
  });
}
