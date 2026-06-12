import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/dashboard_engine/application/telemetry/trace_collector.dart';

final traceCollectorProvider = Provider<TraceCollector>((ref) {
  return TraceCollector();
});