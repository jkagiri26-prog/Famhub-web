class ModuleActivation {
  final String moduleName;
  final bool isEnabled;
  final List<String> allowedRoles;
  final List<String>? regions;
  final int rolloutPercentage;

  const ModuleActivation({
    required this.moduleName,
    required this.isEnabled,
    required this.allowedRoles,
    this.regions,
    this.rolloutPercentage = 100,
  });
}