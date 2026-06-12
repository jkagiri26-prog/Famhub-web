class AccessRule {
  final String resourceKey;
  final bool premiumOnly;
  final bool adminOnly;

  const AccessRule({
    required this.resourceKey,
    required this.premiumOnly,
    required this.adminOnly,
  });

  factory AccessRule.fromMap(Map<String, dynamic> map) {
    return AccessRule(
      resourceKey: map['resource_key'],
      premiumOnly: map['premium_only'] ?? false,
      adminOnly: map['admin_only'] ?? false,
    );
  }
}