class DashboardLayoutBindingRule {
  final String moduleKey;
  final String? role;
  final String? entityId;
  final String device;
  final String layoutKey;
  final int priority;
  final bool isActive;

  const DashboardLayoutBindingRule({
    required this.moduleKey,
    required this.device,
    required this.layoutKey,
    this.role,
    this.entityId,
    this.priority = 0,
    this.isActive = true,
  });

  factory DashboardLayoutBindingRule.fromMap(Map<String, dynamic> map) {
    return DashboardLayoutBindingRule(
      moduleKey: map['module_key'] ?? '',
      role: map['role'],
      entityId: map['entity_id'],
      device: map['device'] ?? 'mobile',
      layoutKey: map['layout_key'] ?? 'default_grid',
      priority: map['priority'] ?? 0,
      isActive: map['is_active'] ?? true,
    );
  }
}