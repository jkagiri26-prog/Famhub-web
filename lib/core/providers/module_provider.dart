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
  final service = ref.read(moduleServiceProvider);
  return service.getActiveModules();
});