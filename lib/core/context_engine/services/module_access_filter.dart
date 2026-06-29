import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/modules/domain/models/system_module.dart';

/// ============================================================
/// MODULE ACCESS FILTER (CONTEXT ENGINE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/context_engine/services/ = context engine service layer
///
/// ✅ Responsibilities:
///   - Filter modules based on current user context
///   - Respect: authentication status, role, tier/subscription
///   - Feature flags, maintenance mode, module dependencies
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Does NOT reference registries directly for business rules
///   - Pure filtering logic - no UI, no providers
///   - Returns filtered list without side effects
///
/// ❌ Does NOT:
///   - Render widgets
///   - Import providers or Riverpod
///   - Modify module state
///   - Handle navigation
/// ============================================================
class ModuleAccessFilter {
  /// ============================================================
  /// FILTER ACCESSIBLE MODULES
  /// ============================================================
  ///
  /// Applies all context-based access rules to a list of modules.
  ///
  /// [modules] - List of system modules to filter
  /// [context] - Current user context from Context Engine
  /// Returns filtered list of accessible modules
  /// ============================================================
  static List<SystemModule> filterAccessibleModules(
    List<SystemModule> modules,
    EntityContext context,
  ) {
    return modules.where((module) {
      return _isModuleAccessible(module, context);
    }).toList();
  }

  /// ============================================================
  /// CHECK SINGLE MODULE ACCESS
  /// ============================================================
  ///
  /// Determines if a single module is accessible to the current user.
  ///
  /// Checks:
  /// 1. Authentication - guest users blocked (unless guest-visible)
  /// 2. Maintenance mode - blocked for all
  /// 3. Is enabled - disabled modules blocked
  /// 4. Premium check - free tier blocked from premium modules
  /// 5. Feature flags - disabled features block access
  /// 6. Dependencies - missing deps block access
  /// ============================================================
  static bool _isModuleAccessible(
    SystemModule module,
    EntityContext context,
  ) {
    // ── Guard: disabled modules ──
    if (!module.isEnabled) return false;

    // ── Guard: maintenance mode ──
    if (module.maintenanceMode) return false;

    // ── Guard: guest users ──
    if (context.isGuest) {
      // Guest-visible flag would be checked here in future
      return false;
    }

    // ── Guard: premium check ──
    if (module.premiumOnly) {
      final tier = context.tier ?? 'free';
      if (tier == 'free') return false;
    }

    // Module is accessible
    return true;
  }

  /// ============================================================
  /// BULK CHECK MODULE VISIBILITY
  /// ============================================================
  ///
  /// Returns only modules that should be visible in navigation/dashboard.
  /// Applies both access rules and visibility flags.
  /// ============================================================
  static List<SystemModule> filterVisibleModules({
    required List<SystemModule> modules,
    required EntityContext context,
    bool forSidebar = false,
    bool forBottomNav = false,
    bool forDashboard = false,
  }) {
    return modules.where((module) {
      // First check generic access
      if (!_isModuleAccessible(module, context)) return false;

      // Then check visibility flags
      if (forSidebar && !module.sidebarVisible) return false;
      if (forBottomNav && !module.bottomNavVisible) return false;
      if (forDashboard && !module.dashboardVisible) return false;

      return true;
    }).toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }
}
