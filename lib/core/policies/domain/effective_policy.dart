/// ============================================================
/// EFFECTIVE POLICY — FULLY RESOLVED LOCATION POLICY
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/policies/domain/ = policy domain models
///
/// EffectivePolicy represents the fully resolved policy document
/// returned by the backend for a specific organization and location.
///
/// This is a pure data model. No business logic. No evaluation.
///
/// ✅ Responsibilities:
///   - Hold the complete set of resolved rules as key-value pairs
///   - Track metadata: locationId, organizationId, version, resolvedAt
///   - Pure data — no evaluation logic
///
/// ❌ Does NOT:
///   - Evaluate rules
///   - Import UI
///   - Contain business logic
/// ============================================================
library;

/// ============================================================
/// EFFECTIVE POLICY
/// ============================================================
///
/// Immutable snapshot of resolved location policies.
/// The backend owns policy resolution. This is the result.
/// ============================================================
class EffectivePolicy {
  /// Map of policy rule key → resolved value
  final Map<String, dynamic> rules;

  /// The location this policy applies to
  final String locationId;

  /// The organization this policy belongs to
  final String organizationId;

  /// Policy version from backend
  final String version;

  /// Timestamp when this policy was resolved
  final DateTime resolvedAt;

  EffectivePolicy({
    this.rules = const {},
    required this.locationId,
    required this.organizationId,
    this.version = '1.0',
    DateTime? resolvedAt,
  }) : resolvedAt = resolvedAt ?? DateTime.now();

  /// ============================================================
  /// QUERY HELPERS
  /// ============================================================

  /// Check if a rule exists in this policy.
  bool hasRule(String key) => rules.containsKey(key);

  /// Get the raw value for a rule. Returns null if not found.
  dynamic getValue(String key) => rules[key];

  /// Get a boolean rule value. Returns false if not found.
  bool getBoolean(String key) {
    final value = rules[key];
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    if (value is int) return value != 0;
    if (value is num) return value != 0;
    return false;
  }

  /// Get an integer rule value. Returns 0 if not found.
  int getNumber(String key) {
    final value = rules[key];
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Get a double rule value. Returns 0.0 if not found.
  double getDecimal(String key) {
    final value = rules[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    if (value is num) return value.toDouble();
    return 0.0;
  }

  /// Get a string rule value. Returns empty string if not found.
  String getString(String key) {
    final value = rules[key];
    return value?.toString() ?? '';
  }

  /// Get a list rule value. Returns empty list if not found.
  List<String> getList(String key) {
    final value = rules[key];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      return value.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }

  /// Number of rules in this policy.
  int get ruleCount => rules.length;

  /// All rule keys in this policy.
  List<String> get ruleKeys => rules.keys.toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EffectivePolicy &&
          runtimeType == other.runtimeType &&
          organizationId == other.organizationId &&
          locationId == other.locationId &&
          version == other.version;

  @override
  int get hashCode =>
      Object.hash(organizationId, locationId, version);

  @override
  String toString() =>
      'EffectivePolicy($organizationId / $locationId v$version — $ruleCount rules)';
}

