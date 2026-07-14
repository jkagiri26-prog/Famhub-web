/// ============================================================
/// POLICY RULE — SINGLE LOCATION RULE VALUE
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/domain/ = policy domain models
///
/// A PolicyRule represents a single key-value pair resolved
/// from the backend for a specific location.
///
/// Examples:
///   WORKFLOW_EXECUTION = true
///   MAX_IMAGE_UPLOAD = 6
///   ENABLE_MARKETPLACE = false
///   REGION_RESTRICTION = ["North", "South"]
///
/// ✅ Responsibilities:
///   - Hold a single resolved rule key and value
///   - Track the source of the rule
///   - Pure data — no business logic
///
/// ❌ Does NOT:
///   - Evaluate rules
///   - Import Flutter
///   - Contain business logic
/// ============================================================
library;

/// ============================================================
/// POLICY RULE
/// ============================================================
///
/// Immutable model for a single resolved policy rule value.
/// ============================================================
class PolicyRule {
  /// The policy rule key (matches Policy.id)
  final String key;

  /// The resolved value (bool, int, double, String, List<String>)
  final dynamic value;

  /// Source identifier (e.g., 'backend', 'default', 'override')
  final String source;

  const PolicyRule({
    required this.key,
    required this.value,
    this.source = 'backend',
  });

  /// ============================================================
  /// CONVENIENCE CASTS
  /// ============================================================

  /// Get the value as a boolean.
  bool get asBoolean {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    if (value is int) return value != 0;
    if (value is num) return value != 0;
    return false;
  }

  /// Get the value as an integer.
  int get asInteger {
    if (value is int) return value;
    if (value is double) return (value).toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return (value).toInt();
    return 0;
  }

  /// Get the value as a double.
  double get asDecimal {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return (value).toDouble();
    return 0.0;
  }

  /// Get the value as a String.
  String get asString => value?.toString() ?? '';

  /// Get the value as a list of strings.
  List<String> get asList {
    if (value is List) {
      return (value as List).map((e) => e.toString()).toList();
    }
    if (value is String) {
      // Support comma-separated string values
      return value.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }

  /// Get the raw dynamic value.
  dynamic get rawValue => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolicyRule &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'PolicyRule($key = $value [$source])';
}
