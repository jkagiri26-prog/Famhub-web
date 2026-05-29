import 'dart:async';
import 'dashboard_refresh_event.dart';

/// ============================================================
/// DASHBOARD EVENT BUS (INTERNAL SIGNAL LAYER)
/// ============================================================
///
/// Lightweight event transport system for dashboard engine.
///
/// Responsibilities:
/// - transport refresh signals
/// - notify composition engine
/// - trigger safe rebuilds
///
/// ❌ NOT responsible for:
/// - state management
/// - layout decisions
/// - module control
/// ============================================================
class DashboardEventBus {
  final StreamController<DashboardRefreshEvent> _controller =
      StreamController<DashboardRefreshEvent>.broadcast();

  /// Global event stream (consumed by providers / engine only)
  Stream<DashboardRefreshEvent> get stream => _controller.stream;

  /// Emit a dashboard refresh event
  void emit(DashboardRefreshEvent event) {
    _controller.add(event);
  }

  /// Safe dispose (engine lifecycle control)
  void dispose() {
    _controller.close();
  }

  /// ============================================================
  /// OPTIONAL SAFETY: CHECK IF BUS IS CLOSED
  /// ============================================================
  bool get isClosed => _controller.isClosed;
}