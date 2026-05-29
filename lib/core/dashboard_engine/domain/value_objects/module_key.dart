import 'package:flutter/foundation.dart';

/// ============================================================
/// MODULE KEY (DOMAIN VALUE OBJECT)
/// ============================================================
///
/// Strongly-typed identifier for modules in dashboard engine.
///
/// Used ONLY for:
/// - composition mapping
/// - runtime adaptation
/// - renderer lookup
/// ============================================================
@immutable
class ModuleKey {
  final String value;

  const ModuleKey(this.value);

  /// ============================================================
  /// VALUE EQUALITY (CRITICAL FOR ENGINE STABILITY)
  /// ============================================================

  @override
  bool operator ==(Object other) {
    return other is ModuleKey && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  /// ============================================================
  /// VALIDATION (LIGHT SAFETY LAYER)
  /// ============================================================

  bool get isValid => value.trim().isNotEmpty;

  /// ============================================================
  /// DEBUG SUPPORT
  /// ============================================================

  @override
  String toString() => 'ModuleKey($value)';
}