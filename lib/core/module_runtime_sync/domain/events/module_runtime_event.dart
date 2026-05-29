enum ModuleRuntimeEventType {
  moduleUpdated,
  installationUpdated,
  permissionUpdated,
  featureFlagUpdated,
}

class ModuleRuntimeEvent {
  const ModuleRuntimeEvent({
    required this.type,
    required this.payload,
  });

  final ModuleRuntimeEventType type;

  final Map<String, dynamic> payload;
}