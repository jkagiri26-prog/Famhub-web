import 'package:flutter/foundation.dart';

/// ============================================================
/// WIDGET IDENTITY (DOMAIN CORE)
/// ============================================================
///
/// Stable identifier for widget mapping in dashboard engine.
///
/// Used ONLY for:
/// - composition mapping
/// - renderer lookup
/// - snapshot diffing
/// ============================================================
@immutable
class WidgetIdentity {
  /// Unique widget key from module definition
  final String widgetKey;

  const WidgetIdentity({
    required this.widgetKey,
  });

  /// ============================================================
  /// VALUE EQUALITY (CRITICAL FOR DIFF ENGINE)
  /// ============================================================

  @override
  bool operator ==(Object other) {
    return other is WidgetIdentity &&
        other.widgetKey == widgetKey;
  }

  @override
  int get hashCode => widgetKey.hashCode;

  /// ============================================================
  /// HELPER
  /// ============================================================

  @override
  String toString() => 'WidgetIdentity($widgetKey)';
}