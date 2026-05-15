import '../modules_control/module_loader.dart';
import '../modules_control/module_contract.dart';

class ModuleRegistry {
  static final List<AppModule> _modules =
      ModuleLoader.loadModules();

  static List<AppModule> getAll() => _modules;

  static AppModule? getByRoute(String route) {
    try {
      return _modules.firstWhere((m) => m.route == route);
    } catch (_) {
      return null;
    }
  }

  static List<AppModule> getByRole(String role) {
    return _modules
        .where((m) => m.allowedRoles.contains(role))
        .toList();
  }
}