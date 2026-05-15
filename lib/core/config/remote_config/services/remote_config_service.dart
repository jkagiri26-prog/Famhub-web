class RemoteConfigService {
  Future<List<ModuleActivation>> fetch() async {
    // call Supabase
    return [
      ModuleActivation(
        moduleName: 'marketplace',
        isEnabled: true,
        allowedRoles: ['farmer', 'trader'],
      ),
      ModuleActivation(
        moduleName: 'finance',
        isEnabled: false,
        allowedRoles: ['admin'],
      ),
    ];
  }
}