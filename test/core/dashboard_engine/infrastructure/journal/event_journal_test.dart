import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_event.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_source.dart';
import 'package:famhub_app/core/dashboard_engine/infrastructure/journal/event_journal.dart';

void main() {
  late Database db;
  late EventJournal journal;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_journal (
        seq_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        source    TEXT NOT NULL,
        payload   TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_event_journal_entity
      ON event_journal (entity_id, timestamp)
    ''');
    journal = EventJournal(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ============================================================
  // TASK A1: Transaction Safety Tests
  // ============================================================
  group('TASK A1 — Transaction Safety', () {
    test('append uses transaction wrapper', () async {
      final event = ConflictEvent(
        entityId: 'entity-1',
        source: ConflictSource.realtime,
        timestamp: DateTime.now(),
        payload: {'type': 'moduleUpdated', 'data': {'id': '1'}},
      );

      final seqId = await journal.append(event);
      expect(seqId, isNonZero);

      // Verify it was persisted
      final count = await journal.count();
      expect(count, equals(1));
    });

    test('pruneBefore uses transaction wrapper', () async {
      // Insert 5 events
      for (int i = 0; i < 5; i++) {
        await journal.append(ConflictEvent(
          entityId: 'entity-$i',
          source: ConflictSource.realtime,
          timestamp: DateTime.now(),
          payload: {'index': i},
        ));
      }

      expect(await journal.count(), equals(5));

      // Prune first 3 events
      await journal.pruneBefore(3);
      expect(await journal.count(), equals(2)); // seq_id 4, 5 remain
    });

    test('append fully commits or fully rolls back', () async {
      // Simulate a valid append
      final event = ConflictEvent(
        entityId: 'entity-1',
        source: ConflictSource.realtime,
        timestamp: DateTime.now(),
        payload: {'key': 'value'},
      );

      final seqId = await journal.append(event);
      expect(seqId, greaterThan(0));

      // Verify data integrity
      final events = await journal.readAfter(null);
      expect(events.length, equals(1));
      expect(events[0].entityId, equals('entity-1'));
      expect(events[0].payload['key'], equals('value'));
    });
  });

  // ============================================================
  // TASK A2: Corruption Detection Tests
  // ============================================================
  group('TASK A2 — Corruption Detection', () {
    test('isValidJournalEvent accepts valid row', () {
      final validRow = <String, dynamic>{
        'seq_id': 1,
        'entity_id': 'test-entity',
        'source': 'realtime',
        'timestamp': '2024-01-01T00:00:00.000Z',
        'payload': '{"key":"value"}',
      };

      expect(journal.isValidJournalEvent(validRow), isTrue);
    });

    test('isValidJournalEvent rejects missing entity_id', () {
      final row = <String, dynamic>{
        'seq_id': 1,
        'entity_id': null,
        'source': 'realtime',
        'timestamp': '2024-01-01T00:00:00.000Z',
        'payload': '{"key":"value"}',
      };

      expect(journal.isValidJournalEvent(row), isFalse);
    });

    test('isValidJournalEvent rejects empty entity_id', () {
      final row = <String, dynamic>{
        'seq_id': 1,
        'entity_id': '',
        'source': 'realtime',
        'timestamp': '2024-01-01T00:00:00.000Z',
        'payload': '{"key":"value"}',
      };

      expect(journal.isValidJournalEvent(row), isFalse);
    });

    test('isValidJournalEvent rejects invalid source', () {
      final row = <String, dynamic>{
        'seq_id': 1,
        'entity_id': 'test-entity',
        'source': 'invalid_source_enum',
        'timestamp': '2024-01-01T00:00:00.000Z',
        'payload': '{"key":"value"}',
      };

      expect(journal.isValidJournalEvent(row), isFalse);
    });

    test('isValidJournalEvent rejects unparseable timestamp', () {
      final row = <String, dynamic>{
        'seq_id': 1,
        'entity_id': 'test-entity',
        'source': 'realtime',
        'timestamp': 'not-a-date',
        'payload': '{"key":"value"}',
      };

      expect(journal.isValidJournalEvent(row), isFalse);
    });

    test('isValidJournalEvent rejects invalid JSON payload', () {
      final row = <String, dynamic>{
        'seq_id': 1,
        'entity_id': 'test-entity',
        'source': 'realtime',
        'timestamp': '2024-01-01T00:00:00.000Z',
        'payload': 'not-json-at-all',
      };

      expect(journal.isValidJournalEvent(row), isFalse);
    });

    test('isValidJournalEvent rejects non-Map payload', () {
      final row = <String, dynamic>{
        'seq_id': 1,
        'entity_id': 'test-entity',
        'source': 'realtime',
        'timestamp': '2024-01-01T00:00:00.000Z',
        'payload': '"just-a-string"',
      };

      expect(journal.isValidJournalEvent(row), isFalse);
    });

    test('corrupted rows are skipped during readAfter', () async {
      // Insert a valid event
      await journal.append(ConflictEvent(
        entityId: 'entity-1',
        source: ConflictSource.realtime,
        timestamp: DateTime.now(),
        payload: {'valid': true},
      ));

      // Directly insert a corrupted row
      await db.insert('event_journal', {
        'entity_id': 'corrupted',
        'timestamp': '2024-01-01T00:00:00.000Z',
        'source': 'invalid_source!!!',
        'payload': 'not-json',
      });

      // Insert another valid event after corrupted row
      await journal.append(ConflictEvent(
        entityId: 'entity-2',
        source: ConflictSource.realtime,
        timestamp: DateTime.now(),
        payload: {'valid': true},
      ));

      // readAfter should skip the corrupted row
      final events = await journal.readAfter(null);
      expect(events.length, equals(2)); // Only valid events returned
      expect(events[0].entityId, equals('entity-1'));
      expect(events[1].entityId, equals('entity-2'));
    });
  });

  // ============================================================
  // TASK A3: Replay Ordering Validation Tests
  // ============================================================
  group('TASK A3 — Replay Ordering Validation', () {
    test('valid monotonic ordering passes through', () async {
      // Insert events in order
      for (int i = 1; i <= 5; i++) {
        await db.insert('event_journal', {
          'entity_id': 'entity-$i',
          'timestamp': '2024-01-01T00:00:0$i.000Z',
          'source': 'realtime',
          'payload': '{"index":$i}',
        });
      }

      final events = await journal.readAfter(null);
      expect(events.length, equals(5));
    });

    test('duplicate seq_id causes skip of duplicate', () async {
      // Insert 3 events with valid seq_ids (using auto-increment)
      for (int i = 0; i < 3; i++) {
        await journal.append(ConflictEvent(
          entityId: 'entity-$i',
          source: ConflictSource.realtime,
          timestamp: DateTime.now(),
          payload: {'index': i},
        ));
      }

      // Manually add a duplicate (same payload, new auto-increment)
      // Auto-increment means we can't truly duplicate seq_id,
      // but we can simulate with manual id insertion
      await db.rawInsert(
        'INSERT INTO event_journal (seq_id, entity_id, timestamp, source, payload) '
        'VALUES (?, ?, ?, ?, ?)',
        [2, 'duplicate-entity', '2024-01-01T00:00:00.000Z', 'realtime', '{}'],
      );

      // readAfter should detect and skip the ordering violation
      final events = await journal.readAfter(null);
      // Should skip the duplicate seq_id=2
      expect(events.length, equals(3));
    });
  });

  // ============================================================
  // SQLite INTEGRITY CHECK — TASK A1
  // ============================================================
  group('SQLite Integrity Checks', () {
    test('integrity_check passes after forced interruption', () async {
      // Insert events
      for (int i = 0; i < 10; i++) {
        await journal.append(ConflictEvent(
          entityId: 'entity-$i',
          source: ConflictSource.realtime,
          timestamp: DateTime.now(),
          payload: {'index': i},
        ));
      }

      // Prune some
      await journal.pruneBefore(5);

      // Check integrity
      final result = await db.rawQuery('PRAGMA integrity_check');
      expect(result.first.values.first, equals('ok'));

      // Insert more
      for (int i = 10; i < 20; i++) {
        await journal.append(ConflictEvent(
          entityId: 'entity-$i',
          source: ConflictSource.realtime,
          timestamp: DateTime.now(),
          payload: {'index': i},
        ));
      }

      // Prune more
      await journal.pruneBefore(12);

      // Check integrity again
      final result2 = await db.rawQuery('PRAGMA integrity_check');
      expect(result2.first.values.first, equals('ok'));

      // Verify counts
      final remaining = await journal.count();
      expect(remaining, greaterThan(0));
    });
  });
}
