import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../telemetry/trace_collector.dart';

final traceCollectorProvider = Provider<TraceCollector>((ref) {
  return TraceCollector();
});