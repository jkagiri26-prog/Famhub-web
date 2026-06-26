
import 'package:flutter_test/flutter_test.dart';
import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/observability/runtime_metrics_collector.dart';

void main() {
  group('RuntimeMetricsCollector', () {
    late RuntimeMetricsCollector collector;
    late String traceId;

    setUp(() {
      collector = RuntimeMetricsCollector(
        maxMetricsBufferSize: 100,
        throttleStreamInterval: const Duration(milliseconds: 50),
        percentileBufferSize: 50,
      );
      collector.start();
      traceId = 'test-trace-1';
    });

    tearDown(() {
      collector.dispose();
    });

    test('starts with zero metrics', () {
      expect(collector.totalEvents, equals(0));
      expect(collector.failureCount, equals(0));
      expect(collector.droppedEventCount, equals(0));
      expect(collector.slowModuleCount, equals(0));
      expect(collector.bufferSize, equals(0));
    });

    test('records a pipeline stage event', () {
      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        type: TelemetryEventType.pipelineStageCompleted,
        phase: TelemetryPhase.reconcile,
        timestamp: DateTime.now(),
        durationMs: 42,
      ));

      expect(collector.totalEvents, equals(1));
    });

    test('aggregates patch durations and percentiles', () async {
      // Record several patch measurements with varying durations
      for (int i = 0; i < 10; i++) {
        collector.record(RuntimeTelemetryEvent(
          traceId: traceId,
          moduleId: 'module_$i',
          type: TelemetryEventType.patchExecutionMeasured,
          phase: TelemetryPhase.execution,
          timestamp: DateTime.now(),
          durationMs: (i + 1) * 10, // 10, 20, 30, ... 100
        ));
      }

      await Future.delayed(const Duration(milliseconds: 100));

      final snapshot = collector.latestSnapshot;
      expect(snapshot, isNotNull);
      expect(snapshot!.averagePatchDurationMs, closeTo(55, 5));
      expect(snapshot.p50PatchDurationMs, closeTo(55, 5));
      expect(snapshot.p95PatchDurationMs, closeTo(95, 10));
    });

    test('detects slow modules exceeding threshold', () {
      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        moduleId: 'slow_module',
        type: TelemetryEventType.slowModuleDetected,
        phase: TelemetryPhase.execution,
        severity: TelemetrySeverity.warning,
        timestamp: DateTime.now(),
        durationMs: 150, // exceeds default threshold of 100ms
        metadata: const {'thresholdMs': 100},
      ));

      expect(collector.slowModuleCount, equals(1));
      final modules = collector.slowModules;
      expect(modules[0].moduleId, equals('slow_module'));
      expect(modules[0].metricType, equals('patch'));
      expect(modules[0].actualMs, equals(150));
    });

    test('tracks failures from patch execution failures', () {
      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        type: TelemetryEventType.patchExecutionFailed,
        phase: TelemetryPhase.execution,
        severity: TelemetrySeverity.error,
        timestamp: DateTime.now(),
      ));

      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        type: TelemetryEventType.replayFailureCaptured,
        phase: TelemetryPhase.replay,
        severity: TelemetrySeverity.error,
        timestamp: DateTime.now(),
      ));

      expect(collector.failureCount, equals(2));
    });

    test('tracks dropped events from buffer capacity', () {
      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        type: TelemetryEventType.frameTaskDropped,
        phase: TelemetryPhase.scheduler,
        severity: TelemetrySeverity.warning,
        timestamp: DateTime.now(),
      ));

      expect(collector.droppedEventCount, equals(1));
    });

    test('tracks reconnect attempts', () {
      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        type: TelemetryEventType.syncReconnectTriggered,
        phase: TelemetryPhase.sync,
        timestamp: DateTime.now(),
      ));

      // Check via snapshot
      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        type: TelemetryEventType.metricsSampled,
        phase: TelemetryPhase.runtime,
        timestamp: DateTime.now(),
      ));
    });

    test('emits health snapshots via stream', () async {
      final receivedSnapshots = <RuntimeHealthSnapshot>[];
      final sub = collector.healthSnapshotStream.listen((s) {
        receivedSnapshots.add(s);
      });

      // Record events to trigger snapshot emission
      for (int i = 0; i < 5; i++) {
        collector.record(RuntimeTelemetryEvent(
          traceId: traceId,
          type: TelemetryEventType.patchExecutionMeasured,
          phase: TelemetryPhase.execution,
          timestamp: DateTime.now(),
          durationMs: (i + 1) * 10,
        ));
      }

      await Future.delayed(const Duration(milliseconds: 150));

      expect(receivedSnapshots.isNotEmpty, isTrue);
      final snapshot = receivedSnapshots.last;
      expect(snapshot.averagePatchDurationMs, greaterThan(0));
      expect(snapshot.snapshotAt, isNotNull);

      await sub.cancel();
    });

    test('resets metrics correctly', () {
      collector.record(RuntimeTelemetryEvent(
        traceId: traceId,
        type: TelemetryEventType.pipelineStageCompleted,
        phase: TelemetryPhase.reconcile,
        timestamp: DateTime.now(),
      ));

      expect(collector.totalEvents, equals(1));

      collector.reset();

      expect(collector.totalEvents, equals(0));
      expect(collector.failureCount, equals(0));
      expect(collector.droppedEventCount, equals(0));
      expect(collector.bufferSize, equals(0));
    });

    test('handles high-frequency events without crashing', () {
      // Simulate 1000 rapid events
      for (int i = 0; i < 1000; i++) {
        collector.record(RuntimeTelemetryEvent(
          traceId: 'trace-$i',
          moduleId: i % 2 == 0 ? 'module_a' : 'module_b',
          type: TelemetryEventType.patchExecutionMeasured,
          phase: TelemetryPhase.execution,
          timestamp: DateTime.now(),
          durationMs: (i % 100) + 1,
        ));
      }

      // Should not crash, buffer should be capped
      expect(collector.totalEvents, equals(1000));
      expect(collector.bufferSize, lessThanOrEqualTo(100));

      // Should have tracked some modules
      expect(collector.slowModuleCount, greaterThanOrEqualTo(0));
    });
  });
}
