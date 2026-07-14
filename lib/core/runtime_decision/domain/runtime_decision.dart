/// ============================================================
/// RUNTIME DECISION — THE SINGLE OUTPUT MODEL
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/runtime_decision/domain/ = domain layer
///
/// A RuntimeDecision is produced by the RuntimeDecisionEngine for
/// EVERY request. It includes:
///   - allowed: Whether the action is permitted
///   - reason: Human-readable explanation
///   - source: Which engine produced the denial
///   - failedChecks: What specific rules/checks failed
///
/// ✅ ARCHITECTURE PRINCIPLE:
///   Every decision must explain itself. No silent denials.
///
/// ✅ USAGE:
///   Widgets, services, and workflows use RuntimeDecision to:
///     - Conditionally render UI
///     - Show explanation messages
///     - Log denied actions for audit
///     - Provide support context
///
/// ❌ Does NOT:
///   - Execute business logic
///   - Access Supabase
///   - Import Flutter UI
/// ============================================================
library;

/// ============================================================
/// RUNTIME DECISION MODEL
/// ============================================================
///
/// The single output of all runtime permission evaluations.
/// ============================================================
class RuntimeDecision {
  /// Whether the action is allowed
  final bool allowed;

  /// Human-readable explanation of the decision
  final String reason;

  /// Which engine produced this decision
  final String source;

  /// List of specific check codes that failed
  final List<String> failedChecks;

  const RuntimeDecision({
    required this.allowed,
    required this.reason,
    required this.source,
    this.failedChecks = const [],
  });

  // ── Convenience factories ──

  /// Create an ALLOW decision with no failed checks
  const RuntimeDecision.allowed()
      : allowed = true,
        reason = 'Action allowed',
        source = 'Runtime Decision Engine',
        failedChecks = const [];

  /// Create a DENY decision with explanation
  const RuntimeDecision.denied({
    required this.reason,
    required this.source,
    this.failedChecks = const [],
  }) : allowed = false;

  // ── Accessors ──

  /// True if action is denied
  bool get isDenied => !allowed;

  /// Human-readable summary for display
  String get summary => allowed
      ? 'Allowed'
      : 'Denied: $reason (Source: $source)';

  // ── Equality ──

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuntimeDecision &&
          allowed == other.allowed &&
          reason == other.reason &&
          source == other.source;

  @override
  int get hashCode => Object.hash(allowed, reason, source);

  @override
  String toString() =>
      'RuntimeDecision(allowed: $allowed, reason: $reason, '
      'source: $source, failedChecks: $failedChecks)';
}
