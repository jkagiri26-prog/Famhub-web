class DashboardRuntimeRefreshPolicy {
  const DashboardRuntimeRefreshPolicy();

  bool shouldRefreshDashboard({
    required bool hasModuleChanges,
  }) {
    return hasModuleChanges;
  }

  bool shouldRefreshNavigation({
    required bool hasModuleChanges,
  }) {
    return hasModuleChanges;
  }
}