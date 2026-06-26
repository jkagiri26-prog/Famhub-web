import 'package:flutter_test/flutter_test.dart';
import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';

void main() {
  group('RuntimeTelemetryEvent', () {
    test('creates with required fields', () {
      final event = RuntimeTelemetryEvent(
        traceId: 'trace-1',
        type: TelemetryEventType.pipelineStageCompleted,
        phase: TelemetryPhase.reconcile,
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        durationMs: 42,
      );

      expect(event.traceId, equals('trace-1'));
      expect(event.type, equals(TelemetryEventType.pipelineStageCompleted));
      expect(event.phase, equals(TelemetryPhase.reconcile));
      expect(event.durationMs, equals(42));
      expect(event.severity, equals(TelemetrySeverity.info));
      expect(event.moduleId, isNull);
      expect(event.widgetKey, isNull);
    });

    test('supports copyWith', () {
      final original = RuntimeTelemetryEvent(
        traceId: 'trace-1',
        type: TelemetryEventType.pipelineStageCompleted,
        phase: TelemetryPhase.reconcile,
        timestamp: DateTime(2024, 1, 1),
      );

      final modified = original.copyWith(
        durationMs: 100,
        severity: TelemetrySeverity.warning,
      );

      expect(modified.traceId, equals('trace-1'));
      expect(modified.durationMs, equals(100));
      expect(modified.severity, equals(TelemetrySeverity.warning));
      expect(modified.type, equals(original.type));
    });

    test('serializes to JSON and back', () {
      final original = RuntimeTelemetryEvent(
        traceId: 'trace-json',
        moduleId: 'module_x',
        widgetKey: 'widget_y',
        runtimeSessionId: 'session-abc',
        type: TelemetryEventType.patchExecutionMeasured,
        phase: TelemetryPhase.execution,
        severity: TelemetrySeverity.info,
        timestamp: DateTime(2024, 6, 15, 10, 30, 0),
        durationMs: 75,
        metadata: const {'batchId': 'batch-123'},
      );

      final json = original.toJson();
      final restored = RuntimeTelemetryEvent.fromJson(json);

      expect(restored.traceId, equals(original.traceId));
      expect(restored.moduleId, equals(original.moduleId));
      expect(restored.widgetKey, equals(original.widgetKey));
      expect(restored.runtimeSessionId, equals(original.runtimeSessionId));
      expect(restored.type, equals(original.type));
      expect(restored.phase, equals(original.phase));
      expect(restored.severity, equals(original.severity));
      expect(restored.durationMs, equals(original.durationMs));
      expect(restored.metadata['batchId'], equals('batch-123'));
    });

    test('uses value equality', () {
      final a = RuntimeTelemetryEvent(
        traceId: 't1',
        type: TelemetryEventType.pipelineStageCompleted,
        phase: TelemetryPhase.reconcile,
        timestamp: DateTime(2024, 1, 1),
      );

      final b = RuntimeTelemetryEvent(
        traceId: 't1',
        type: TelemetryEventType.pipelineStageCompleted,
        phase: TelemetryPhase.reconcile,
        timestamp: DateTime(2024, 1, 1),
      );

      final c = RuntimeTelemetryEvent(
        traceId: 't2',
        type: TelemetryEventType.pipelineStageCompleted,
        phase: TelemetryPhase.reconcile,
        timestamp: DateTime(2024, 1, 1),
      );

      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
      expect(a == c, isFalse);
    });
  });

  group('RuntimeHealthSnapshot', () {
    test('creates with default values', () {
      final snapshot = RuntimeHealthSnapshot(
        snapshotAt: DateTime(2024, 1, 1),
      );

      expect(snapshot.healthStatus, equals(RuntimeHealthStatus.healthy));
      expect(snapshot.averagePatchDurationMs, equals(0));
      expect(snapshot.failureCount, equals(0));
      expect(snapshot.slowestModules, isEmpty);
    });

    test('serializes to JSON', () {
      final snapshot = RuntimeHealthSnapshot(
        replayedEventCount: 100,
        averagePatchDurationMs: 42.5,
        failureCount: 2,
        healthStatus: RuntimeHealthStatus.degraded,
        snapshotAt: DateTime(2024, 6, 15),
      );

      final json = snapshot.toJson();
      expect(json['replayedEventCount'], equals(100));
      expect(json['averagePatchDurationMs'], equals(42.5));
      expect(json['failureCount'], equals(2));
      expect(json['healthStatus'], equals('degraded'));
    });
  });

  group('SlowModuleInfo', () {
    test('creates with required fields', () {
      final info = SlowModuleInfo(
        moduleId: 'module_x',
        metricType: 'patch',
        thresholdMs: 100,
        actualMs: 250,
        detectedAt: DateTime(2024, 1, 1),
      );

      expect(info.moduleId, equals('module_x'));
      expect(info.actualMs, equals(250));
      expect(info.occurrenceCount, equals(1));
    });

    test('increments occurrence count via copyWith', () {
      final info = SlowModuleInfo(
        moduleId: 'module_x',
        metricType: 'patch',
        thresholdMs: 100,
        actualMs: 250,
        detectedAt: DateTime(2024, 1, 1),
      );

      final updated = info.copyWith(occurrenceCount: 5);
      expect(updated.occurrenceCount, equals(5));
      expect(updated.moduleId, equals('module_x'));
    });

    test('serializes to JSON', () {
      final info = SlowModuleInfo(
        moduleId: 'module_x',
        widgetKey: 'widget_y',
        metricType: 'replay',
        thresholdMs: 500,
        actualMs: 1200,
        detectedAt: DateTime(2024, 6, 15),
        occurrenceCount: 3,
      );

      final json = info.toJson();
      expect(json['moduleId'], equals('module_x'));
      expect(json['widgetKey'], equals('widget_y'));
      expect(json['metricType'], equals('replay'));
      expect(json['actualMs'], equals(1200));
      expect(json['occurrenceCount'], equals(3));
    });
  });
}
