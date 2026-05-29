import 'package:flutter/widgets.dart';
import 'widget_builder_registry.dart';

/// ============================================================
/// WIDGET BUILDER RESOLVER
/// ============================================================
///
/// Converts widgetKey → Flutter Widget using registry.
///
/// This is the FINAL presentation resolution step.
///
/// ❌ NOT responsible for:
/// - layout decisions
/// - composition logic
/// - module resolution
/// ============================================================
class WidgetBuilderResolver {
  /// Resolve widget from registry
  Widget resolve(String widgetKey) {
    final builder = WidgetBuilderRegistry.resolve(widgetKey);

    if (builder == null) {
      // ============================================================
      // DEBUG SAFE FALLBACK
      // ============================================================
      _onMissingWidget(widgetKey);

      return const SizedBox.shrink();
    }

    return builder();
  }

  /// ============================================================
  /// DEBUG HOOK (NO BUSINESS IMPACT)
  /// ============================================================
  void _onMissingWidget(String widgetKey) {
    // Safe hook for debugging / telemetry later
    // Example future use:
    // - log missing widget
    // - send analytics event
    // - track misconfigurations
  }
}