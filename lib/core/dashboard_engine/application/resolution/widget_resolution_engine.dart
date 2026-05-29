import 'package:flutter/widgets.dart';

import '../../presentation/builders/widget_builder_registry.dart';

/// ============================================================
/// WIDGET RESOLUTION ENGINE (SINGLE SOURCE OF TRUTH)
/// ============================================================
///
/// Responsible for resolving widgetKey → Widget.
///
/// ❌ MUST NOT:
/// - know about layout
/// - know about composition
/// - know about modules directly
/// ============================================================

class WidgetResolutionEngine {
  const WidgetResolutionEngine();

  Widget resolve({
    required String widgetKey,
    required String moduleKey,
    Map<String, dynamic> config = const {},
  }) {
    final builder = WidgetBuilderRegistry.resolve(widgetKey);

    if (builder != null) {
      return builder();
    }

    /// SAFE FALLBACK
    return SizedBox(
      key: ValueKey(widgetKey),
      child: Text('Missing widget: $widgetKey'),
    );
  }
}