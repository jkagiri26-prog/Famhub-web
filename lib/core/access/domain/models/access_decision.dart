enum AccessDecisionType {
  allow,
  deny,
  upgradeRequired,
}

class AccessDecision {
  final AccessDecisionType type;
  final String? reason;

  const AccessDecision({
    required this.type,
    this.reason,
  });

  bool get allowed => type == AccessDecisionType.allow;
}