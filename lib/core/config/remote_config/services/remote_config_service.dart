import '../models/module_activation.dart';

class RemoteConfigService {
  Future<List<ModuleActivation>> fetch() async {
    // call Supabase
    return [
      const ModuleActivation(
        moduleName: 'marketplace',
        isEnabled: true,
        allowedRoles: ['farmer', 'trader'],
      ),
      const ModuleActivation(
        moduleName: 'finance',
        isEnabled: false,
        allowedRoles: ['admin'],
      ),
    ];
  }
}