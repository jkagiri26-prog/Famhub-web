class ModuleRuntimeState {
  const ModuleRuntimeState({
    required this.activeModules,
    required this.disabledModules,
    required this.maintenanceModules,
    required this.lastSyncedAt,
  });

  final Set<String> activeModules;
  final Set<String> disabledModules;
  final Set<String> maintenanceModules;

  final DateTime? lastSyncedAt;

  factory ModuleRuntimeState.initial() {
    return const ModuleRuntimeState(
      activeModules: {},
      disabledModules: {},
      maintenanceModules: {},
      lastSyncedAt: null,
    );
  }

  ModuleRuntimeState copyWith({
    Set<String>? activeModules,
    Set<String>? disabledModules,
    Set<String>? maintenanceModules,
    DateTime? lastSyncedAt,
  }) {
    return ModuleRuntimeState(
      activeModules: activeModules ?? this.activeModules,
      disabledModules:
          disabledModules ?? this.disabledModules,
      maintenanceModules:
          maintenanceModules ??
          this.maintenanceModules,
      lastSyncedAt:
          lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}