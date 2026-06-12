class AccessPolicy {
  final Map<String, List<String>> rolePermissions;
  final Map<String, dynamic> featureTiers;

  const AccessPolicy({
    required this.rolePermissions,
    required this.featureTiers,
  });

  factory AccessPolicy.empty() {
    return const AccessPolicy(
      rolePermissions: {},
      featureTiers: {},
    );
  }
}