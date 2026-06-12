import 'package:famhub_app/core/dashboard_engine/application/telemetry/dashboard_trace_event.dart';

class TraceCollector {
  static const int _maxBufferSize = 1000;

  final List<DashboardTraceEvent> _buffer = [];

  void log(DashboardTraceEvent event) {
    if (_buffer.length >= _maxBufferSize) {
      _buffer.removeAt(0);
    }
    _buffer.add(event);
  }

  List<DashboardTraceEvent> dump() {
    return List.unmodifiable(_buffer);
  }

  void clear() {
    _buffer.clear();
  }
}