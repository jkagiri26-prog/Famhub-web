import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/core/dashboard_engine/presentation/builders/widget_builder_registry.dart';
import 'package:famhub_app/core/dashboard_engine/infrastructure/services/module_governance_service.dart';

import '../presentation/builders/widget_builder_registry.dart';

/// ============================================================
/// DASHBOARD BOOTSTRAP (SYSTEM-DRIVEN OS INITIALIZER v2)
/// ============================================================
///
/// Deterministic, idempotent bootstrap layer for dashboard engine.
/// Builds widget registry from system modules.
///
/// RULES:
/// - Safe to call multiple times (idempotent)
/// - No UI logic
/// - No rendering concerns
/// - No global mutation outside registry
/// ============================================================

class DashboardBootstrap {
  DashboardBootstrap._();

  static bool _ready = false;

  /// ============================================================
  /// MAIN ENTRY
  /// ============================================================
  static Future<void> initializeFromSystem() async {
    /// Idempotent guard (safe for hot restart / re-init)
    if (_ready) return;

    /// STEP 1: LOAD SYSTEM MODULES (source of truth)
    final repository = ModuleRepository();
    final governance = ModuleGovernanceService();
    final allModules = await repository.fetchEnabledModules();
    final List<SystemModule> modules = governance.applyRules(allModules);

    /// STEP 2: EXTRACT WIDGET BUILDERS
    final Map<String, DashboardWidgetBuilder> builders =
        _extractWidgetBuilders(modules);

    /// STEP 3: VALIDATE REGISTRY BEFORE BOOTSTRAP
    _validateBuilders(builders);

    /// STEP 4: BOOTSTRAP INTO GLOBAL REGISTRY
    WidgetBuilderRegistry.bootstrap(
      initialBuilders: builders,
    );

    _ready = true;
  }

  /// ============================================================
  /// WIDSystemModule> modules,
  ) {
    final Map<String, DashboardWidgetBuilder> builders = {};

    for (final module in modules) {
      /// For now, create default builder based on moduleKey
      /// Real widget builders come from WidgetBuilderRegistry.register()
      /// called during module initialization
      builders.putIfAbsent(
        module.moduleKey,
        () => _missingWidget(module.moduleKey),
      );   widgetKey,
          () => _missingWidget(widgetKey),
        )
      }
    }

    return builders;
  }

  /// ============================================================
  /// VALIDATION LAYER (SAFEGUARD AGAINST BAD REGISTRY)
  /// ============================================================
  void _validateBuilders(
    Map<String, DashboardWidgetBuilder> builders,
  ) {
    if (builders.isEmpty) {
      throw StateError(
        'DashboardBootstrap: No widgets registered from system modules',
      );
    }
  }

  /// ============================================================
  /// FALLBACK WIDGET
  /// ============================================================
  DashboardWidgetBuilder _missingWidget(
    String widgetKey,
  ) {
    return () => Center(
          child: Text(
            'Missing widget: $widgetKey',
          ),
        );
  }

  /// ============================================================
  /// SYSTEM STATUS
  /// ============================================================
  bool get isReady => _ready;

  /// ============================================================
  /// RESET (FOR TESTING / HOT RELOAD RECOVERY ONLY)
  /// ============================================================
  void resetForTest() {
    _ready = false;
  }
}