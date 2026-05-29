import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_event_bus.dart';

/// ============================================================
/// EVENT BUS PROVIDER (HARD SINGLETON BOUNDARY)
/// ============================================================
/// RULES:
/// - Must NOT create new instances
/// - Must NOT dispose global bus
/// - Must remain stateless wrapper only
final eventBusProvider = Provider<AppEventBus>((ref) {
  /// Always bind to singleton instance
  final bus = AppEventBus.instance;

  /// ==========================================================
  /// SAFETY NOTE:
  /// DO NOT attach listeners here
  /// DO NOT mutate bus state here
  /// ==========================================================

  ref.onDispose(() {
    /// Intentionally empty:
    /// AppEventBus is a global runtime singleton
    /// Lifecycle is managed at app level only
  });

  return bus;
});