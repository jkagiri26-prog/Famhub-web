import 'package:supabase_flutter/supabase_flutter.dart';
import '../../system/modules_control/module_definition.dart';

class ModuleService {
  final SupabaseClient _client = Supabase.instance.client;

  List<Module>? _cache;

  /// 🚀 PUBLIC ENTRY: Get active modules
  Future<List<Module>> getActiveModules() async {
    if (_cache != null) return _cache!;

    final response = await _client
        .from('system.modules')
        .select('module_key, module_name, is_enabled, dashboard_visible, maintenance_mode');

    final List data = response;

    final modules = data
        .where((m) =>
            m['is_enabled'] == true &&
            m['dashboard_visible'] == true &&
            m['maintenance_mode'] == false)
        .map<Module>((m) {
      return _mapModule(m);
    }).toList();

    _cache = modules;
    return modules;
  }

  /// 🔄 Manual refresh (admin, feature flags, etc.)
  Future<List<Module>> refreshModules() async {
    _cache = null;
    return getActiveModules();
  }

  /// 🧩 MAP backend → frontend module
  Module _mapModule(Map m) {
    final key = m['module_key'];

    switch (key) {
      case 'farm_management':
        return Module(
          key: key,
          name: m['module_name'],
          builder: () => _loadFarmModule(),
        );

      // Future modules
      // case 'marketplace':
      //   return Module(...)

      default:
        return Module(
          key: key,
          name: m['module_name'],
          builder: () => _fallbackModule(m['module_name']),
        );
    }
  }

  /// 🚜 Existing module hook (NO REBUILD)
  Widget _loadFarmModule() {
    // Import your existing module page here
    return const Placeholder(); // replace with FarmDashboardPage()
  }

  Widget _fallbackModule(String name) {
    return Center(child: Text("Module: $name"));
  }
}