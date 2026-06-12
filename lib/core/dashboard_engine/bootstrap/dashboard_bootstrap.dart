import 'package:flutter/widgets.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_builder_registry.dart';
/// ============================================================
/// DASHBOARD BOOTSTRAP (SYSTEM-DRIVEN OS INITIALIZER v2)
/// ============================================================
///
/// Deterministic, idempotent bootstrap layer for dashboard engine.
/// Builds widget registry from system modules.
///
/// RULES:
/// - Safe to call multiple times (idempotent)
/// - No UI logic
/// - No rendering concerns
/// - No global mutation outside registry
/// ============================================================

class DashboardBootstrap {
  DashboardBootstrap._();

  static bool _ready = false;

  /// ============================================================
  /// MAIN ENTRY
  /// ============================================================
  static Future<void> initialize({
    required Map<String, DashboardWidgetBuilder> builders,
  }) async {
    if (_ready) return;

    if (builders.isEmpty) {
      throw StateError(
        'DashboardBootstrap: No widget builders provided',
      );
    }

    for (final entry in builders.entries) {
      WidgetBuilderRegistry.register(
        widgetKey: entry.key,
        builder: entry.value,
      );
    }

    _ready = true;
  }

  /// ============================================================
  /// SYSTEM STATUS
  /// ============================================================
  static bool get isReady => _ready;

  /// ============================================================
  /// RESET (FOR TESTING / HOT RELOAD RECOVERY ONLY)
  /// ============================================================
  static void resetForTest() {
    _ready = false;
    WidgetBuilderRegistry.clear();
  }
}