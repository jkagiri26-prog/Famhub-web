import 'package:flutter/foundation.dart';

/// ============================================================
/// WIDGET KEY (DOMAIN VALUE OBJECT)
/// ============================================================
///
/// Strong identifier for widget resolution in dashboard engine.
///
/// Used ONLY for:
/// - composition mapping
/// - renderer lookup
/// - snapshot diffing
/// ============================================================
@immutable
class WidgetKey {
  final String value;

  const WidgetKey(this.value);

  /// ============================================================
  /// VALUE EQUALITY (CRITICAL FOR DIFF + CACHE)
  /// ============================================================

  @override
  bool operator ==(Object other) {
    return other is WidgetKey && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  /// ============================================================
  /// LIGHT VALIDATION
  /// ============================================================

  bool get isValid => value.trim().isNotEmpty;

  /// ============================================================
  /// DEBUG SUPPORT
  /// ============================================================

  @override
  String toString() => 'WidgetKey($value)';
}