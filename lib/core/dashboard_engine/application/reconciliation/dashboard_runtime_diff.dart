class DashboardRuntimeDiff {
  const DashboardRuntimeDiff({
    required this.addedModules,
    required this.removedModules,
    required this.maintenanceChangedModules,
    required this.requiresRefresh,
  });

  final Set<String> addedModules;
  final Set<String> removedModules;
  final Set<String> maintenanceChangedModules;

  final bool requiresRefresh;

  factory DashboardRuntimeDiff.empty() {
    return const DashboardRuntimeDiff(
      addedModules: {},
      removedModules: {},
      maintenanceChangedModules: {},
      requiresRefresh: false,
    );
  }

  bool get hasChanges {
    return addedModules.isNotEmpty ||
        removedModules.isNotEmpty ||
        maintenanceChangedModules.isNotEmpty;
  }
}