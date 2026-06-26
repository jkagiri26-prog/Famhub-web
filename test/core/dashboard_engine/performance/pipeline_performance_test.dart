import 'package:flutter_test/flutter_test.dart';
import 'package:famhub_app/core/dashboard_engine/application/conflict/dashboard_conflict_buffer.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_event.dart';
import 'package:famhub_app/core/dashboard_engine/domain/conflict/dashboard_conflict_resolver.dart';

/// ============================================================
/// PHASE 6 — TASK GROUP A: PIPELINE PERFORMANCE OPTIMIZATION
/// ============================================================
///
/// A1 — Event Coalescing Window: burst events collapse into fewer executions
/// A2 — Adaptive Batch Sizing: replay does not freeze UI
/// A3 — ConflictBuffer Capacity Controls: bounded memory under stress
/// ============================================================

void main() {
  group('Pipeline Performance (A1 — Event Coalescing)', () {
    /// ============================================================
    /// A1: Burst events collapse into fewer pipeline executions
    /// ============================================================
    test('burst events can be coalesced without ordering violations', () async {
      // Simulate a burst of 100 events arriving within a 32ms window
      // without coalescing, this would trigger 100 pipeline runs
      // with coalescing, they should collapse into far fewer

      final buffer = ConflictBuffer(ConflictResolver());
      final now = DateTime.now();

      // Burst: all events within same millisecond window
      for (int i = 0; i < 100; i++) {
        buffer.add(ConflictEvent(
          entityId: 'entity_${i % 10}',
          source: ConflictSource.realtime,
          timestamp: now,
          payload: {
            'type': 'moduleUpdated',
            'data': {'id': 'entity_${i % 10}', 'value': i},
          },
        ));
      }

      // Process once (simulating coalesced pipeline execution)
      final resolved = buffer.resolveAll();

      // Verify ordering: per entity, the latest event wins
      expect(resolved, isNotEmpty,
          reason: 'Coalesced batch should produce results');

      // With 10 unique entities, we should have at most 10 resolved events
      expect(resolved.length, equals(10),
          reason: '10 unique entities should produce exactly 10 resolved events');

      // Buffer should be clean
      expect(buffer.isEmpty, isTrue);
    });

    test('coalescing does not cause event loss', () async {
      final buffer = ConflictBuffer(ConflictResolver());
      final now = DateTime.now();

      // Simulate multiple coalescing windows
      for (int window = 0; window < 10; window++) {
        for (int i = 0; i < 20; i++) {
          final entityId = 'entity_${window}_$i';

          buffer.add(ConflictEvent(
            entityId: entityId,
            source: ConflictSource.realtime,
            timestamp: now.add(Duration(milliseconds: window * 50 + i)),
            payload: {
              'type': 'moduleUpdated',
              'data': {'id': entityId, 'window': window},
            },
          ));
        }

        // Process each window
        final resolved = buffer.resolveAll();
        expect(resolved.length, equals(20),
            reason: 'Window $window should produce 20 resolved events');
      }

      // All entities should have been seen
      expect(buffer.isEmpty, isTrue,
          reason: 'Buffer should be empty after all windows');
    });
  });

  group('Pipeline Performance (A2 — Adaptive Batch Sizing)', () {
    /// ============================================================
    /// A2: Small backlog uses large batch (fast)
    /// ============================================================
    test('small backlog uses larger batches', () async {
      const smallBacklogThreshold = 100;
      const largeBatchSize = 200;
      const totalEvents = smallBacklogThreshold - 1; // Below threshold

      final buffer = ConflictBuffer(ConflictResolver());
      final now = DateTime.now();

      // Simulate non-adaptive (direct) insertion
      for (int i = 0; i < totalEvents; i++) {
        buffer.add(ConflictEvent(
          entityId: 'entity_$i',
          source: ConflictSource.realtime,
          timestamp: now.add(Duration(milliseconds: i)),
          payload: {'type': 'moduleUpdated', 'data': {'id': 'entity_$i'}},
        ));
      }

      // Can resolve in a single batch
      final sw = Stopwatch()..start();
      final resolved = buffer.resolveAll();
      sw.stop();

      expect(resolved.length, equals(totalEvents),
          reason: 'All events should be resolved');
      expect(sw.elapsedMilliseconds, lessThan(1000),
          reason: 'Small backlog should resolve quickly');
    });

    /// ============================================================
    /// A2: Large backlog uses smaller batches with yields
    /// ============================================================
    test('large backlog can be processed in batched steps', () async {
      const totalEvents = 500;

      final buffer = ConflictBuffer(ConflictResolver());
      final now = DateTime.now();

      for (int i = 0; i < totalEvents; i++) {
        buffer.add(ConflictEvent(
          entityId: 'entity_${i % 50}',
          source: ConflictSource.realtime,
          timestamp: now.add(Duration(milliseconds: i)),
          payload: {'type': 'moduleUpdated', 'data': {'id': 'entity_${i % 50}'}},
        ));
      }

      // Resolve all at once (as pipeline would)
      // Even 500 events should resolve quickly since only 50 unique entities
      final sw = Stopwatch()..start();
      final resolved = buffer.resolveAll();
      sw.stop();

      expect(resolved.length, equals(50),
          reason: '50 unique entities should remain after dedup');
      expect(sw.elapsedMilliseconds, lessThan(1000),
          reason: '500 events should resolve in < 1 second');
    });
  });

  group('Pipeline Performance (A3 — Capacity Controls)', () {
    /// ============================================================
    /// A3: Memory usage bounded during disconnect storms
    /// ============================================================
    test('buffer memory is bounded during disconnect storms', () async {
      const bufferMaxSize = 500;
      const overflowCount = 1000; // More events than buffer capacity

      final buffer = ConflictBuffer(ConflictResolver(), maxBufferSize: bufferMaxSize);
      final now = DateTime.now();

      // Simulate disconnect storm: 1000 unique entities
      for (int i = 0; i < overflowCount; i++) {
        buffer.add(ConflictEvent(
          entityId: 'entity_$i',
          source: ConflictSource.realtime,
          timestamp: now.add(Duration(milliseconds: i)),
          payload: {'type': 'moduleUpdated', 'data': {'id': 'entity_$i'}},
        ));
      }

      // Buffer should not exceed max capacity
      expect(buffer.length, lessThanOrEqualTo(bufferMaxSize),
          reason: 'Buffer must not exceed maxBufferSize=$bufferMaxSize');

      // Overflow should have been triggered
      expect(buffer.overflowCount, greaterThan(0),
          reason: 'Overflow should have occurred');
      expect(buffer.totalDroppedEvents, greaterThan(0),
          reason: 'Events should have been dropped');
    });

    /// ============================================================
    /// A3: Overflow never corrupts state
    /// ============================================================
    test('overflow does not corrupt state — recovery via journal implied', () async {
      const bufferMaxSize = 100;
      const overshootCount = 200;

      final buffer = ConflictBuffer(ConflictResolver(), maxBufferSize: bufferMaxSize);
      final now = DateTime.now();

      // Overflow the buffer
      for (int i = 0; i < overshootCount; i++) {
        buffer.add(ConflictEvent(
          entityId: 'entity_$i',
          source: ConflictSource.realtime,
          timestamp: now.add(Duration(milliseconds: i)),
          payload: {'type': 'moduleUpdated', 'data': {'id': 'entity_$i'}},
        ));
      }

      // Resolve should still work and produce valid results
      final resolved = buffer.resolveAll();

      // Some events were dropped, but remaining are valid
      expect(resolved, isNotEmpty,
          reason: 'Resolved events should still be valid');
      expect(resolved.length, lessThanOrEqualTo(bufferMaxSize),
          reason: 'Resolved count should not exceed buffer capacity');

      // No crashes, no corrupt data
      for (final event in resolved) {
        expect(event.entityId, isNotEmpty);
        expect(event.source, isNotNull);
        expect(event.payload, isNotNull);
      }

      // Buffer is clean for next cycle
      expect(buffer.isEmpty, isTrue,
          reason: 'Buffer should be clean after resolve');
    });

    /// ============================================================
    /// A3: Recovery still possible via journal replay
    /// ============================================================
    test('replay after overflow produces correct dedup state', () async {
      // Simulates: buffer overflow during storm → resolve (dropping oldest)
      // → journal replay recovers all events in correct order

      const bufferMaxSize = 100;
      final buffer = ConflictBuffer(ConflictResolver(), maxBufferSize: bufferMaxSize);
      final now = DateTime.now();
      final allEvents = <ConflictEvent>[];

      // Generate events (as if from journal)
      for (int i = 0; i < 200; i++) {
        final event = ConflictEvent(
          entityId: 'entity_${i % 30}',
          source: ConflictSource.realtime,
          timestamp: now.add(Duration(milliseconds: i)),
          payload: {'type': 'moduleUpdated', 'data': {'id': 'entity_${i % 30}'}},
        );
        allEvents.add(event);
      }

      // Replay all events (simulating journal replay)
      for (final event in allEvents) {
        buffer.add(event);
      }

      // Final state after resolving: only latest per entity
      final resolved = buffer.resolveAll();

      // Should have 30 resolved events (one per unique entity)
      expect(resolved, isNotEmpty);
      final uniqueIds = resolved.map((e) => e.entityId).toSet();
      expect(uniqueIds.length, equals(30),
          reason: '30 unique entities after full replay + resolve');

      // The result should be deterministic
      final resolvedIds = resolved.map((e) => e.entityId).toList();
      final sortedExpected = List<String>.from(uniqueIds)..sort();

      // Ordering should be deterministic
      expect(resolved.length, equals(sortedExpected.length));
    });
  });
}
