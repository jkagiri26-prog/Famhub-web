import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/dashboard_engine/domain/observability/observability_telemetry_event.dart';
import 'package:famhub_app/core/dashboard_engine/application/observability/runtime_metrics_collector.dart';
import 'package:famhub_app/core/dashboard_engine/application/observability/pipeline_instrumentation_adapter.dart';

void main() {
  group('PipelineInstrumentationAdapter', () {
    late RuntimeMetricsCollector collector;
    late String traceId;

    setUp(() {
      collector = RuntimeMetricsCollector(
        throttleStreamInterval: const Duration(milliseconds: 50),
      );
      collector.start();
      traceId = 'test-instrumentation';
    });

    tearDown(() {
      collector.dispose();
    });

    test('PatchInstrumentation.measure records success', () async {
      await PatchInstrumentation.measure(
        collector: collector,
        patchId: 'patch-1',
        moduleId: 'module_x',
        traceId: traceId,
        action: () async => 'result',
      );

      expect(collector.totalEvents, greaterThanOrEqualTo(1));
    });

    test('PatchInstrumentation.measure records failure', () async {
      try {
        await PatchInstrumentation.measure(
          collector: collector,
          patchId: 'patch-2',
          moduleId: 'module_y',
          traceId: traceId,
          action: () async => throw Exception('Test failure'),
        );
      } catch (_) {
        // Expected
      }

      expect(collector.totalEvents, greaterThanOrEqualTo(1));
      expect(collector.failureCount, greaterThanOrEqualTo(1));
    });

    test('ReplayInstrumentation.measure records start and completion', () async {
      await ReplayInstrumentation.measure(
        collector: collector,
        traceId: traceId,
        eventCount: 50,
        action: () async => 'replay done',
      );

      expect(collector.totalEvents, greaterThanOrEqualTo(2));
    });

    test('ReplayInstrumentation.measure records failure', () async {
      try {
        await ReplayInstrumentation.measure(
          collector: collector,
          traceId: traceId,
          eventCount: 10,
          action: () async => throw Exception('Replay failed'),
        );
      } catch (_) {
        // Expected
      }

      expect(collector.totalEvents, greaterThanOrEqualTo(2));
      expect(collector.failureCount, greaterThanOrEqualTo(1));
    });

    test('FrameSchedulerInstrumentation reports backlog warnings', () async {
      final instrumentation = FrameSchedulerInstrumentation(
        collector: collector,
        traceId: traceId,
      );

      // Trigger backlog warning (backlog >= 10)
      instrumentation.onBacklogWarning(15);

      expect(collector.totalEvents, greaterThanOrEqualTo(1));

      // Trigger critical backlog (backlog >= 30)
      instrumentation.onBacklogWarning(35);

      expect(collector.totalEvents, greaterThanOrEqualTo(3));
    });

    test('FrameSchedulerInstrumentation reports dropped tasks', () async {
      final instrumentation = FrameSchedulerInstrumentation(
        collector: collector,
        traceId: traceId,
      );

      instrumentation.onDroppedTask();

      expect(collector.droppedEventCount, equals(1));
    });
  });
}
