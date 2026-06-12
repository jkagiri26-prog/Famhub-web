import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';

/// ============================================================
/// MODULE STATE PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// Provides a map of module state keyed by module identifier.
///
/// 🧠 LOCATION CONTEXT:
///   core/feature_flags/application/providers/
///     = runtime feature state (correct location)
/// ============================================================

final moduleStateProvider = FutureProvider<Map<String, SystemModule>>((ref) async {
  final moduleService = ref.read(moduleServiceProvider);
  final modules = await moduleService.getActiveModules();

  return {
    for (final module in modules) module.moduleKey: module,
  };
});