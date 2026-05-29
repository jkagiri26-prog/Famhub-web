import 'dashboard_trace_event.dart';

class TraceCollector {
  final List<DashboardTraceEvent> _buffer = [];

  void log(DashboardTraceEvent event) {
    _buffer.add(event);
  }

  List<DashboardTraceEvent> dump() {
    return List.unmodifiable(_buffer);
  }

  void clear() {
    _buffer.clear();
  }
}