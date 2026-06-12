import 'package:famhub_app/core/access/access_decision_engine.dart';
import 'package:famhub_app/core/subscription/domain/models/subscription_tier.dart';
import 'package:famhub_app/system/registry/module_registry.dart';

/// ============================================================
/// MODULE ACCESS BRIDGE (RUNTIME ACCESS EVALUATION)
/// ============================================================
///
/// Bridges static registry definitions with runtime
/// access evaluation.
///
/// 🧠 LOCATION CONTEXT:
///   core/module_runtime_sync/ = runtime sync layer
///   system/registry/ = static definitions (consumed here)
///
/// ✅ Correct: Uses registry for lookups, engine for evaluation
/// ❌ Does NOT: Import UI, providers, or Supabase
/// ============================================================
class ModuleAccessBridge {
  final AccessDecisionEngine engine;

  const ModuleAccessBridge({
    required this.engine,
  });

  /// ============================================================
  /// FILTER MODULES THROUGH ACCESS SYSTEM
  /// ============================================================
  ///
  /// Uses static ModuleRegistry for blueprint lookup
  /// and AccessDecisionEngine for runtime evaluation.
  /// ============================================================
  List<String> filterAllowedModules({
    required List<String> moduleKeys,
    required String role,
    required SubscriptionTier tier,
  }) {
    if (moduleKeys.isEmpty) {
      return const [];
    }

    final allowed = <String>{};

    for (final rawKey in moduleKeys) {
      final moduleKey = rawKey.trim();

      if (moduleKey.isEmpty) {
        continue;
      }

      /// Verify module exists in static registry
      final module = ModuleRegistry.byId(moduleKey);

      /// Unknown module — skip
      if (module == null) {
        continue;
      }

      final decision = engine.evaluate(
        featureKey: moduleKey,
        permission: 'view_$moduleKey',
        role: role,
        userTier: tier,
      );

      if (decision.allowed) {
        allowed.add(moduleKey);
      }
    }

    return List.unmodifiable(allowed);
  }
}