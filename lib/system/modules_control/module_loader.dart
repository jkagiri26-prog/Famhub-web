import '../../core/modules/application/providers/module_repository_provider.dart';
import '../../core/modules_control/module_contract.dart';

class ModuleLoader {
  static List<AppModule> loadModulesFromBackend(List<AppModule> modules) {
    // Only allow modules enabled by backend governance
    return modules.where((m) {
      final config = moduleConfigProvider.get(m.moduleKey);

      if (config == null) return false;

      return config.isEnabled && !config.maintenanceMode;
    }).toList();
  }
}