class ModuleCapability {
  final String moduleKey;
  final bool isEnabled;
  final bool maintenanceMode;
  final String? description;
  final int priority;

  const ModuleCapability({
    required this.moduleKey,
    required this.isEnabled,
    required this.maintenanceMode,
    this.description,
    this.priority = 999,
  });

  factory ModuleCapability.fromMap(Map<String, dynamic> map) {
    return ModuleCapability(
      moduleKey: map['module_key'],
      isEnabled: map['is_enabled'] ?? false,
      maintenanceMode: map['maintenance_mode'] ?? false,
      description: map['description'],
      priority: map['priority'] ?? 999,
    );
  }
}