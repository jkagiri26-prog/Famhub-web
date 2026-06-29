import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/providers/module_provider.dart';
import 'package:famhub_app/core/feature_flags/application/services/runtime_feature_flags.dart';

/// ============================================================
/// GOVERNANCE PROVIDER (APPLICATION LAYER)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/feature_flags/application/providers/
///     = runtime feature flags (correct location)
///
/// ✅ Responsibilities:
///   - Evaluate module access using RuntimeFeatureFlags
///   - Combine context engine + feature flags
///   - Reactive to context/module changes
///
/// ❌ Does NOT:
///   - Import UI
///   - Render widgets
///   - Mutate state
/// ============================================================

/// ============================================================
/// PROVIDER: ALLOWED MODULE KEYS
/// ============================================================
///
/// Returns a set of module keys that pass all governance checks
/// for the current user context.
/// ============================================================
final allowedModuleKeysProvider = Provider<Set<String>>((ref) {
  final modulesAsync = ref.watch(moduleProvider);
  final context = ref.watch(contextProvider);

  return modulesAsync.whenOrNull(
    data: (modules) {
      final allowed = <String>{};
      for (final module in modules) {
        final result = RuntimeFeatureFlags.evaluateModule(
          module: module,
          context: context,
        );
        if (result.isAllowed) {
          allowed.add(module.moduleKey);
        }
      }
      return allowed;
    },
  ) ?? <String>{};
});

/// ============================================================
/// PROVIDER: DENIED MODULE KEYS WITH REASON
/// ============================================================
///
/// Returns a map of module keys to their denial reasons
/// for debugging and diagnostics.
/// ============================================================
final deniedModuleKeysProvider = Provider<Map<String, String>>((ref) {
  final modulesAsync = ref.watch(moduleProvider);
  final context = ref.watch(contextProvider);

  return modulesAsync.whenOrNull(
    data: (modules) {
      final denied = <String, String>{};
      for (final module in modules) {
        final result = RuntimeFeatureFlags.evaluateModule(
          module: module,
          context: context,
        );
        if (!result.isAllowed && result.denialReason != null) {
          denied[module.moduleKey] = result.denialReason!;
        }
      }
      return denied;
    },
  ) ?? <String, String>{};
});

/// ============================================================
/// PROVIDER: MODULE ACCESS CHECK
/// ============================================================
///
/// Check if a specific module key is accessible.
/// Reactive — updates when context or modules change.
/// ============================================================
final moduleAccessProvider = Provider.family<bool, String>((ref, moduleKey) {
  final allowedKeys = ref.watch(allowedModuleKeysProvider);
  return allowedKeys.contains(moduleKey);
});
