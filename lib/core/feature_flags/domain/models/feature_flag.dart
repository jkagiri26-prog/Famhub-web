class FeatureFlag {
  final String featureKey;
  final bool isEnabled;
  final bool premiumOnly;
  final bool adminOnly;
  final bool maintenanceMode;
  final String? description;
  final int priority;

  const FeatureFlag({
    required this.featureKey,
    required this.isEnabled,
    required this.premiumOnly,
    required this.adminOnly,
    required this.maintenanceMode,
    this.description,
    this.priority = 999,
  });

  factory FeatureFlag.fromMap(Map<String, dynamic> map) {
    return FeatureFlag(
      featureKey: map['feature_key'],
      isEnabled: map['is_enabled'] ?? false,
      premiumOnly: map['premium_only'] ?? false,
      adminOnly: map['admin_only'] ?? false,
      maintenanceMode: map['maintenance_mode'] ?? false,
      description: map['description'],
      priority: map['priority'] ?? 999,
    );
  }
}