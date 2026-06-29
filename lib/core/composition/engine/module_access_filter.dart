import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/composition/domain/models/composition_metrics.dart';

/// ============================================================
/// MODULE ACCESS FILTER (COMPOSITION ENGINE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/engine/ = composition engine layer
///
/// ✅ Responsibilities:
///   - Apply EntityContext-based filtering to RuntimeModules
///   - Determine WHY a module was denied (for observability)
///   - Pure filtering — no side effects, no I/O
///
/// ✅ DIFFERENCE FROM ModuleAccessFilter in context_engine:
///   - Works on RuntimeModule (final resolved form) instead of SystemModule
///   - Operates on already-mapped modules
///   - Adds denial reason tracking for metrics
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - User-specific filtering happens HERE, not in widgets
///   - NO hardcoded role checks (if role == "farmer") in UI
///   - All rules come from backend metadata (SystemModule fields)
///
/// FILTERING LAYER (this class):
///   ↓
/// Access Filter works on RuntimeModules after dependency resolution
///
/// RULES APPLIED:
///   1. Module is enabled (isEnabled == true)
///   2. Module is not in maintenance mode
///   3. Guest users: block unless supportsGuest == true
///   4. Premium check: block free tier users if premiumOnly
///   5. Subscription check: block free tier if requiresSubscription
///   6. Entity check: block if requiresEntity but no entityId
///   7. Farm check: block if requiresFarm but no entityId
///   8. Business check: block if requiresBusiness but no entityId
/// ============================================================
class ModuleAccessFilter {
  /// ============================================================
  /// FILTER MODULES BY CONTEXT
  /// ============================================================
  ///
  /// Returns only modules that pass ALL access rules for the
  /// given EntityContext.
  ///
  /// [modules] - List of RuntimeModules to filter
  /// [context] - Current EntityContext from Context Engine
  /// [metrics] - Optional metrics collector for tracking denial reasons
  /// Returns filtered list of accessible modules
  /// ============================================================
  List<RuntimeModule> filterModules({
    required List<RuntimeModule> modules,
    required EntityContext context,
    CompositionMetricsCollector? metrics,
  }) {
    final result = <RuntimeModule>[];

    for (final module in modules) {
      final reason = _checkAccess(module, context);

      if (reason == null) {
        // Module passed all checks
        result.add(module);
      } else {
        // Module denied — track the reason
        final deniedModule = module.copyWith(
          isEnabled: false,
          denialReason: reason,
        );
        result.add(deniedModule);
        metrics?.recordModuleDenied(reason);
      }
    }

    return result;
  }

  /// ============================================================
  /// CHECK SINGLE MODULE ACCESS
  /// ============================================================
  ///
  /// Returns null if accessible, or a string denial reason.
  /// ============================================================
  String? _checkAccess(RuntimeModule module, EntityContext context) {
    // ── 1. Module enabled check ──
    if (!module.isEnabled) {
      return 'module_disabled';
    }

    // ── 2. Maintenance mode ──
    if (module.maintenanceMode) {
      return 'maintenance_mode';
    }

    // ── 3. Guest user check ──
    if (context.isGuest && !module.supportsGuest) {
      return 'guest_restricted';
    }

    // ── 4. Premium check ──
    if (module.premiumOnly) {
      final tier = context.tier ?? 'free';
      if (tier == 'free') {
        return 'premium_required';
      }
    }

    // ── 5. Subscription check ──
    if (module.requiresSubscription) {
      final tier = context.tier ?? 'free';
      if (tier == 'free') {
        return 'subscription_required';
      }
    }

    // ── 6. Entity check ──
    if (module.requiresEntity) {
      if (context.entityId == null || context.entityId!.isEmpty) {
        return 'entity_required';
      }
    }

    // ── 7. Farm check ──
    if (module.requiresFarm) {
      if (context.entityId == null || context.entityId!.isEmpty) {
        return 'farm_required';
      }
    }

    // ── 8. Business check ──
    if (module.requiresBusiness) {
      if (context.entityId == null || context.entityId!.isEmpty) {
        return 'business_required';
      }
    }

    // ── All checks passed ──
    return null;
  }

  /// ============================================================
  /// BULK VISIBILITY CHECK
  /// ============================================================
  ///
  /// Returns only modules that pass access rules AND
  /// match the requested visibility flag.
  /// ============================================================
  List<RuntimeModule> filterVisibleModules({
    required List<RuntimeModule> modules,
    required EntityContext context,
    bool forSidebar = false,
    bool forBottomNav = false,
    bool forDashboard = false,
    bool forQuickAction = false,
    bool onlyPinned = false,
    CompositionMetricsCollector? metrics,
  }) {
    // First apply access filtering
    final accessible = filterModules(
      modules: modules,
      context: context,
      metrics: metrics,
    );

    // Then apply visibility+pin filtering
    return accessible.where((m) {
      if (!m.isEnabled) return false;
      if (forSidebar && !m.sidebarVisible) return false;
      if (forBottomNav && !m.bottomNavVisible) return false;
      if (forDashboard && !m.dashboardVisible) return false;
      if (forQuickAction && !m.quickActionVisible) return false;
      if (onlyPinned && !m.pinned) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;
        return a.displayOrder.compareTo(b.displayOrder);
      });
  }
}
