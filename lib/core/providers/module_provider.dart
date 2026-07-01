import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/services/module_service.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';

/// ============================================================
/// MODULE PROVIDERS (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/providers/ = application state management
///
/// ✅ Correct: Uses runtime services for data fetching
/// ❌ Does NOT: Import UI, registry, or Supabase directly
/// ============================================================

final moduleServiceProvider = Provider((ref) => ModuleService());

final moduleProvider = FutureProvider<List<SystemModule>>((ref) async {
  debugPrint('[MODULE_PROVIDER] Started — entering provider factory');
  final service = ref.read(moduleServiceProvider);
  debugPrint('[MODULE_PROVIDER] Service obtained, calling getActiveModules()...');
  try {
    final result = await service.getActiveModules();
    debugPrint('[MODULE_PROVIDER] SUCCESS — got ${result.length} modules');
    return result;
  } catch (e, stack) {
    debugPrint('[MODULE_PROVIDER] FAILED — error: $e');
    debugPrint('[MODULE_PROVIDER] Stack: $stack');
    rethrow;
  }
});