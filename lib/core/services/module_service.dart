import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';

/// ============================================================
/// MODULE SERVICE (RUNTIME DATA ACCESS LAYER)
/// ============================================================
///
/// Responsibility:
/// - Fetch module data from backend (Supabase)
/// - Transform to domain models
///
/// 🧠 LOCATION CONTEXT:
///   core/services/ = runtime service layer
///
/// ❌ DOES NOT:
///   - Import UI widgets
///   - Return Flutter Widgets
///   - Perform business evaluation
/// ============================================================
class ModuleService {
  final SupabaseClient _client = Supabase.instance.client;

  List<SystemModule>? _cache;

  /// 🚀 PUBLIC ENTRY: Get active modules
  Future<List<SystemModule>> getActiveModules() async {
    if (_cache != null) return _cache!;

    debugPrint('[MODULE_SVC] Fetching modules via .schema(system).from(modules)...');

    try {
                final response = await _client
        .schema('system')
        .from('modules')
        .select('module_key, module_name, is_enabled, '
            'dashboard_visible, sidebar_visible, bottom_nav_visible, '
            'quick_action_visible, launcher_visible, '
            'desktop_only, mobile_only, tablet_only, '
            'maintenance_mode, maintenance_message, '
            'premium_only, requires_subscription, '
            'requires_entity, requires_farm, requires_business, '
            'requires_verification, '
            'display_order, badge_text, badge_color, '
            'notification_count_source, icon_color, '
            'section, category, group, '
            'parent_module, sort_group, '
            'default_open, pinned');

      debugPrint('[MODULE_SVC] Response type: ${response.runtimeType}');
    final List data = response;
      debugPrint('[MODULE_SVC] Row count: ${data.length}');
      if (data.isNotEmpty) {
        debugPrint('[MODULE_SVC] First row keys: ${(data.first as Map).keys}');
      }

    final modules = data
        .map<SystemModule>((m) {
      return SystemModule.fromMap(m as Map<String, dynamic>);
    }).toList();

    _cache = modules;
      debugPrint('[MODULE_SVC] Parsed ${modules.length} modules successfully');
    return modules;
    } catch (e, stack) {
      debugPrint('[MODULE_SVC] QUERY FAILED: $e');
      debugPrint('[MODULE_SVC] Stack: $stack');

      if (e is PostgrestException) {
        debugPrint('[MODULE_SVC] PostgrestException:');
        debugPrint('  message: ${e.message}');
        debugPrint('  code: ${e.code}');
        debugPrint('  details: ${e.details}');
        debugPrint('  hint: ${e.hint}');
  }
      rethrow; // Let the provider's error state catch it
    }
  }

  /// 🔄 Manual refresh (admin, feature flags, etc.)
  Future<List<SystemModule>> refreshModules() async {
    _cache = null;
    return getActiveModules();
}
}