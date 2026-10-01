import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/features/logistics/application/services/logistics_location_point_queue.dart';

QueuedLocationPoint _point(
  String key, {
  double latitude = -1.2921,
  int attempts = 0,
}) {
  return QueuedLocationPoint(
    idempotencyKey: key,
    trackingSessionId: 'sess-1',
    capturedAt: DateTime.parse('2026-03-12T10:00:00Z'),
    latitude: latitude,
    longitude: 36.8219,
    attempts: attempts,
  );
}

void main() {
  group('LogisticsLocationPointQueue', () {
    test('keeps points in capture order', () {
      final queue = LogisticsLocationPointQueue();

      queue
        ..add(_point('a'))
        ..add(_point('b'))
        ..add(_point('c'));

      expect(queue.length, 3);
      expect(queue.pending.map((p) => p.idempotencyKey), ['a', 'b', 'c']);
    });

    test('is bounded and evicts the oldest point at the cap', () {
      final queue = LogisticsLocationPointQueue(maxSize: 3);

      for (var i = 0; i < 6; i++) {
        queue.add(_point('p$i'));
      }

      expect(queue.length, 3);
      expect(queue.isFull, isTrue);
      expect(queue.pending.map((p) => p.idempotencyKey), ['p3', 'p4', 'p5']);
    });

    test('add reports the evicted point so callers can stay aware', () {
      final queue = LogisticsLocationPointQueue(maxSize: 2)
        ..add(_point('a'))
        ..add(_point('b'));

      final evicted = queue.add(_point('c'));

      expect(evicted, isNotNull);
      expect(evicted!.idempotencyKey, 'a');
      expect(queue.pending.map((p) => p.idempotencyKey), ['b', 'c']);
    });

    test('re-adding the same idempotency key never duplicates a point', () {
      final queue = LogisticsLocationPointQueue()
        ..add(_point('same', latitude: 1))
        ..add(_point('same', latitude: 2));

      expect(queue.length, 1);
      expect(queue.pending.single.latitude, 2);
      expect(queue.pending.single.idempotencyKey, 'same');
    });

    test('remove drops only the matching point', () {
      final queue = LogisticsLocationPointQueue()
        ..add(_point('a'))
        ..add(_point('b'));

      expect(queue.remove('a'), isTrue);
      expect(queue.remove('a'), isFalse);
      expect(queue.length, 1);
      expect(queue.pending.single.idempotencyKey, 'b');
    });

    test('clear empties the buffer', () {
      final queue = LogisticsLocationPointQueue()
        ..add(_point('a'))
        ..add(_point('b'))
        ..clear();

      expect(queue.isEmpty, isTrue);
      expect(queue.length, 0);
    });

    test('a failed attempt keeps the ORIGINAL idempotency key', () {
      final original = _point('key-1', attempts: 0);

      final retried = original.withFailedAttempt().withFailedAttempt();

      expect(retried.idempotencyKey, original.idempotencyKey);
      expect(retried.attempts, 2);
      expect(retried.trackingSessionId, original.trackingSessionId);
      expect(retried.capturedAt, original.capturedAt);
      expect(retried.latitude, original.latitude);
      expect(retried.longitude, original.longitude);
    });
  });

  group('generateLocationIdempotencyKey', () {
    test('produces distinct RFC 4122 version 4 uuids', () {
      final keys = <String>{};
      for (var i = 0; i < 500; i++) {
        keys.add(generateLocationIdempotencyKey());
      }

      expect(keys, hasLength(500));
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      for (final key in keys) {
        expect(pattern.hasMatch(key), isTrue, reason: key);
      }
    });

    test('is deterministic for a seeded random in tests', () {
      final first = generateLocationIdempotencyKey(Random(7));
      final second = generateLocationIdempotencyKey(Random(7));

      expect(first, second);
    });
  });
}
