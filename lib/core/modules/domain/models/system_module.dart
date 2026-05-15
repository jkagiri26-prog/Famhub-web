class SystemModule {
  final String moduleKey;
  final String displayName;
  final bool isEnabled;
  final bool dashboardVisible;
  final bool maintenanceMode;
  final bool premiumOnly;
  final int displayOrder;

  const SystemModule({
    required this.moduleKey,
    required this.displayName,
    required this.isEnabled,
    required this.dashboardVisible,
    required this.maintenanceMode,
    required this.premiumOnly,
    required this.displayOrder,
  });

  factory SystemModule.fromMap(Map<String, dynamic> map) {
    return SystemModule(
      moduleKey: map['module_key'],
      displayName: map['display_name'],
      isEnabled: map['is_enabled'] ?? false,
      dashboardVisible: map['dashboard_visible'] ?? false,
      maintenanceMode: map['maintenance_mode'] ?? false,
      premiumOnly: map['premium_only'] ?? false,
      displayOrder: map['display_order'] ?? 999,
    );
  }
}
