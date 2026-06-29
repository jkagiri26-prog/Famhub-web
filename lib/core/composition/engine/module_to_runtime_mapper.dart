import 'package:famhub_app/core/modules/domain/models/system_module.dart';
import 'package:famhub_app/system/registry/module_registry.dart';
import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';

/// ============================================================
/// MODULE TO RUNTIME MAPPER (COMPOSITION ENGINE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/engine/ = composition engine layer
///
/// ✅ Responsibilities:
///   - Convert SystemModule (backend DTO) → RuntimeModule (composition model)
///   - Enrich with static metadata from ModuleRegistry
///   - Pure mapping — no side effects, no I/O, no filtering
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Uses only SystemModule fields + ModuleRegistry lookups
///   - No UI references, no providers
///   - Deterministic mapping
/// ============================================================
class ModuleToRuntimeMapper {
  /// ============================================================
  /// MAP SYSTEM MODULE TO RUNTIME MODULE
  /// ============================================================
  ///
  /// Converts a backend-driven SystemModule into a fully-enriched
  /// RuntimeModule ready for composition.
  ///
  /// Enrichment includes:
  ///   - Route resolution from ModuleRegistry
  ///   - Icon resolution from ModuleRegistry
  ///   - Dashboard metadata mapping
  ///   - Widget builder key assignment
  /// ============================================================
  RuntimeModule mapToRuntime(SystemModule module) {
    // Resolve static metadata from ModuleRegistry
    final def = ModuleRegistry.byId(module.moduleKey);

    // Resolve route from registry, fallback to /moduleId
    final route = def?.entryRoute ?? '/${module.moduleKey}';

    // Use module_key as default widget builder key
    final widgetBuilderKey = module.moduleKey;

    // Map dashboard section from SystemModule fields
    final dashboardSection = module.section ?? module.category;

    return RuntimeModule(
      moduleId: module.moduleKey,
      displayName: module.displayName,
      description: module.displayName,
      route: route,
      iconKey: def?.iconKey ?? 'widgets',
      displayOrder: module.displayOrder,

      // ── Visibility ──
      sidebarVisible: module.sidebarVisible,
      bottomNavVisible: module.bottomNavVisible,
      dashboardVisible: module.dashboardVisible,
      quickActionVisible: module.quickActionVisible,
      launcherVisible: module.launcherVisible,

      // ── State ──
      isEnabled: module.isEnabled,
      maintenanceMode: module.maintenanceMode,
      maintenanceMessage: module.maintenanceMessage,

      // ── Grouping ──
      section: module.section,
      category: module.category,
      group: module.group,
      sortGroup: module.sortGroup,
      parentModuleId: module.parentModule,

      // ── Badge ──
      badgeText: module.badgeText,
      badgeColor: module.badgeColor,
      notificationCountSource: module.notificationCountSource,

      // ── Pinning ──
      pinned: module.pinned,
      defaultOpen: module.defaultOpen,

      // ── Device ──
      desktopOnly: module.desktopOnly,
      mobileOnly: module.mobileOnly,
      tabletOnly: module.tabletOnly,

      // ── Governance ──
      premiumOnly: module.premiumOnly,
      requiresSubscription: module.requiresSubscription,
      requiresEntity: module.requiresEntity,
      requiresFarm: module.requiresFarm,
      requiresBusiness: module.requiresBusiness,
      requiresVerification: module.requiresVerification,

      // ── Dashboard ──
      dashboardSection: dashboardSection,
      dashboardPriority: module.displayOrder,

      // ── Widget ──
      widgetBuilderKey: widgetBuilderKey,

      // ── Capabilities (defaults from module metadata) ──
      supportsGuest: true,
      supportsOffline: true,
      supportsSync: true,
      supportsSearch: true,
      supportsNotifications: true,
    );
  }

  /// ============================================================
  /// BATCH MAP
  /// ============================================================
  ///
  /// Maps a list of SystemModules to RuntimeModules.
  /// ============================================================
  List<RuntimeModule> mapAll(List<SystemModule> modules) {
    return modules.map(mapToRuntime).toList();
  }
}
