/// ============================================================
/// CONTRIBUTION REGISTRATION BOOTSTRAP (PHASE C)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/bootstrap/ = composition bootstrapping
///
/// ✅ Responsibilities:
///   - Register all module contributions into ContributionRegistry
///   - Bridges ModuleRuntimeDescriptor contributions into the
///     runtime ContributionRegistry for enterprise-level querying
///   - Called once during app initialization
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Each module's runtime descriptor is the SOURCE of truth
///   - This bootstrap converts descriptors → ContributionRegistry entries
///   - No hardcoded module-specific logic here
///   - The RuntimeContributionEngine queries both sources
///
/// ✅ WHY THIS EXISTS:
///   The ModuleDescriptorRegistry stores ModuleRuntimeDescriptors which
///   contain *Descriptor types (DashboardWidgetDescriptor, etc.).
///   The ContributionRegistry stores *Contribution types
///   (DashboardWidgetContribution, etc.). This bridge converts between them.
///
///   Over time, modules can directly register Contribution types
///   for more dynamic/reactive contributions. For now, we derive
///   contributions from descriptors automatically.
/// ============================================================
library;

import 'package:famhub_app/core/composition/domain/models/module_descriptor_registry.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/composition/contributions/contribution_registry.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';

/// ============================================================
/// BOOTSTRAP ALL MODULE CONTRIBUTIONS
/// ============================================================
///
/// Call this after bootstrapModuleDescriptors() during app init.
/// Registers each module's descriptor contributions into the
/// ContributionRegistry for enterprise-level composition.
/// ============================================================
void bootstrapModuleContributions() {
  // Iterate all registered module descriptors and bridge them
  for (final moduleKey in ModuleDescriptorRegistry.registeredModuleKeys) {
    final descriptor = ModuleDescriptorRegistry.get(moduleKey);
    if (descriptor == null) continue;

    _registerDescriptorContributions(descriptor);
  }
}

/// ============================================================
/// BRIDGE: ModuleRuntimeDescriptor → ContributionRegistry
/// ============================================================
///
/// Converts a module's runtime descriptor contributions into
/// the ContributionRegistry format for enterprise-level queries.
/// ============================================================
void _registerDescriptorContributions(ModuleRuntimeDescriptor descriptor) {
  final moduleId = descriptor.moduleKey;

  // ── 1. Dashboard Widgets ──
  final dashboardWidgets = descriptor.dashboardWidgets
      .map(
        (dw) => DashboardWidgetContribution(
          widgetKey: dw.widgetKey,
          displayName: dw.displayName,
          sectionKey: dw.sectionKey,
          displayOrder: dw.displayOrder,
          width: dw.width,
          height: dw.height,
          isVisibleByDefault: dw.isVisibleByDefault,
          iconKey: dw.iconKey,
          refreshIntervalSeconds: dw.refreshIntervalSeconds,
        ),
      )
      .toList();

  // ── 2. Home Widgets ──
  final homeWidgets = descriptor.homeWidgets
      .map(
        (hw) => HomeWidgetContribution(
          widgetKey: hw.widgetKey,
          widgetType: hw.widgetType,
          displayName: hw.displayName,
          displayOrder: hw.displayOrder,
          iconKey: hw.iconKey,
          priority: hw.priority,
          isVisibleByDefault: hw.isVisibleByDefault,
        ),
      )
      .toList();

  // ── 3. Quick Actions ──
  final quickActions = descriptor.quickActions
      .map(
        (qa) => QuickActionContribution(
          actionKey: qa.actionKey,
          label: qa.label,
          iconKey: qa.iconKey,
          displayOrder: qa.displayOrder,
          isVisibleByDefault: qa.isVisibleByDefault,
          route: qa.route,
          isPrimary: qa.isPrimary,
          moduleId: moduleId,
        ),
      )
      .toList();

  // ── 4. Routes ──
  final routes = descriptor.routes
      .map(
        (r) => RouteContribution(
          path: r.path,
          name: r.name,
          isPrimary: r.isPrimary,
          displayOrder: r.displayOrder,
          moduleId: moduleId,
        ),
      )
      .toList();

  // ── 5. Notification Providers ──
  final notificationProviders = descriptor.notificationProviders
      .map(
        (np) => NotificationProviderContribution(
          providerKey: np.providerKey,
          displayName: np.displayName,
          category: moduleId,
          notificationTypes: np.notificationTypes,
          enabledByDefault: np.enabledByDefault,
        ),
      )
      .toList();

  // ── 6. Search Providers ──
  final searchProviders = descriptor.searchProviders.expand((sp) {
    return sp.entityTypes.map(
      (entityType) => SearchProviderContribution(
        providerKey: '${sp.providerKey}_$entityType',
        displayName: sp.displayName,
        entityType: entityType,
        searchRepository: '${moduleId}_$entityType',
        enabledByDefault: sp.enabledByDefault,
      ),
    );
  }).toList();

  // ── 7. Analytics Providers ──
  final analyticsProviders = descriptor.analyticsProviders
      .map(
        (ap) => AnalyticsProviderContribution(
          providerKey: ap.providerKey,
          displayName: ap.displayName,
          metricKeys: ap.metricKeys,
          enabledByDefault: ap.enabledByDefault,
        ),
      )
      .toList();

  // ── 8. AI Providers (Enterprise Phase) ──
  final aiProviders = descriptor.aiProviders
      .map(
        (ai) => AIProviderContribution(
          providerKey: ai.providerKey,
          displayName: ai.displayName,
          capability: ai.capability,
          description: ai.description,
          priority: ai.priority,
          enabledByDefault: ai.enabledByDefault,
          configuration: ai.configuration,
        ),
      )
      .toList();

  // ── 9. Command Palette Actions (Enterprise Phase) ──
  final commandPaletteActions = descriptor.commandPaletteActions
      .map(
        (cpa) => CommandPaletteActionContribution(
          actionKey: cpa.actionKey,
          label: cpa.label,
          description: cpa.description,
          category: cpa.category,
          iconKey: cpa.iconKey,
          route: cpa.route,
          actionId: cpa.actionId,
          priority: cpa.priority,
          keywords: cpa.keywords,
          enabledByDefault: cpa.enabledByDefault,
          moduleId: moduleId,
        ),
      )
      .toList();

  // ── 10. Background Jobs (Enterprise Phase) ──
  final backgroundJobs = descriptor.backgroundJobs
      .map(
        (bj) => BackgroundJobContribution(
          jobKey: bj.jobKey,
          displayName: bj.displayName,
          description: bj.description,
          schedule: bj.schedule,
          enabledByDefault: bj.enabledByDefault,
          priority: bj.priority,
        ),
      )
      .toList();

  // ── 11. Floating Action Buttons (Enterprise Phase) ──
  final floatingActionButtons = descriptor.floatingActionButtons
      .map(
        (fab) => FloatingActionButtonContribution(
          actionKey: fab.actionKey,
          label: fab.label,
          iconKey: fab.iconKey,
          route: fab.route,
          actionId: fab.actionId,
          priority: fab.priority,
          screenRoute: fab.screenRoute,
          enabledByDefault: fab.enabledByDefault,
        ),
      )
      .toList();

  // ── 12. Settings Pages (Enterprise Phase) ──
  final settingsPages = descriptor.settingsPages
      .map(
        (sp) => SettingsPageContribution(
          settingsKey: sp.settingsKey,
          displayName: sp.displayName,
          description: sp.description,
          iconKey: sp.iconKey,
          category: sp.category,
          displayOrder: sp.displayOrder,
          route: sp.route,
          enabledByDefault: sp.enabledByDefault,
        ),
      )
      .toList();

  // ── 13. Reports (Enterprise Phase) ──
  final reports = descriptor.reports
      .map(
        (r) => ReportContribution(
          reportKey: r.reportKey,
          displayName: r.displayName,
          description: r.description,
          iconKey: r.iconKey,
          category: r.category,
          displayOrder: r.displayOrder,
          enabledByDefault: r.enabledByDefault,
        ),
      )
      .toList();

  // ── 14. Export Providers (Enterprise Phase) ──
  final exportProviders = descriptor.exportProviders
      .map(
        (ep) => ExportProviderContribution(
          providerKey: ep.providerKey,
          displayName: ep.displayName,
          formats: ep.formats,
          entityTypes: ep.entityTypes,
          enabledByDefault: ep.enabledByDefault,
        ),
      )
      .toList();

  // ── 15. Import Providers (Enterprise Phase) ──
  final importProviders = descriptor.importProviders
      .map(
        (ip) => ImportProviderContribution(
          providerKey: ip.providerKey,
          displayName: ip.displayName,
          formats: ip.formats,
          entityTypes: ip.entityTypes,
          enabledByDefault: ip.enabledByDefault,
        ),
      )
      .toList();

  // ── 16. Activity Timeline Items (Enterprise Phase) ──
  final activityTimelineItems = descriptor.activityTimelineItems
      .map(
        (ati) => ActivityTimelineItemContribution(
          activityKey: ati.activityKey,
          displayName: ati.displayName,
          iconKey: ati.iconKey,
          category: ati.category,
          displayOrder: ati.displayOrder,
          enabledByDefault: ati.enabledByDefault,
        ),
      )
      .toList();

  // ── 17. Help Articles (Enterprise Phase) ──
  final helpArticles = descriptor.helpArticles
      .map(
        (ha) => HelpArticleContribution(
          articleKey: ha.articleKey,
          title: ha.title,
          summary: ha.summary,
          category: ha.category,
          tags: ha.tags,
          displayOrder: ha.displayOrder,
          enabledByDefault: ha.enabledByDefault,
        ),
      )
      .toList();

  // ── 18. Context Menus (Enterprise Phase) ──
  final contextMenus = descriptor.contextMenus
      .map(
        (cm) => ContextMenuContribution(
          actionKey: cm.actionKey,
          label: cm.label,
          iconKey: cm.iconKey,
          entityType: cm.entityType,
          displayOrder: cm.displayOrder,
          destructive: cm.destructive,
          route: cm.route,
          actionId: cm.actionId,
          enabledByDefault: cm.enabledByDefault,
        ),
      )
      .toList();

  // ── 19. Entity Actions (Enterprise Phase) ──
  final entityActions = descriptor.entityActions
      .map(
        (ea) => EntityActionContribution(
          actionKey: ea.actionKey,
          label: ea.label,
          iconKey: ea.iconKey,
          entityType: ea.entityType,
          displayOrder: ea.displayOrder,
          route: ea.route,
          actionId: ea.actionId,
          isPrimary: ea.isPrimary,
          enabledByDefault: ea.enabledByDefault,
        ),
      )
      .toList();

  // ── 20. Workflow Steps (Enterprise Phase) ──
  final workflowSteps = descriptor.workflowSteps
      .map(
        (ws) => WorkflowStepContribution(
          stepKey: ws.stepKey,
          displayName: ws.displayName,
          description: ws.description,
          workflowKey: ws.workflowKey,
          stepOrder: ws.stepOrder,
          enabledByDefault: ws.enabledByDefault,
        ),
      )
      .toList();

  // ── 21. Approval Actions (Enterprise Phase) ──
  final approvalActions = descriptor.approvalActions
      .map(
        (aa) => ApprovalActionContribution(
          actionKey: aa.actionKey,
          displayName: aa.displayName,
          description: aa.description,
          entityType: aa.entityType,
          requiredRoles: aa.requiredRoles,
          enabledByDefault: aa.enabledByDefault,
        ),
      )
      .toList();

  // ── Register all contributions for this module ──
  ContributionRegistry.registerModule(
    moduleId: moduleId,
    dashboardWidgets: dashboardWidgets,
    homeWidgets: homeWidgets,
    quickActions: quickActions,
    routes: routes,
    notificationProviders: notificationProviders,
    searchProviders: searchProviders,
    analyticsProviders: analyticsProviders,
    aiProviders: aiProviders,
    commandPaletteActions: commandPaletteActions,
    backgroundJobs: backgroundJobs,
    floatingActionButtons: floatingActionButtons,
    settingsPages: settingsPages,
    reports: reports,
    exportProviders: exportProviders,
    importProviders: importProviders,
    activityTimelineItems: activityTimelineItems,
    helpArticles: helpArticles,
    contextMenus: contextMenus,
    entityActions: entityActions,
    workflowSteps: workflowSteps,
    approvalActions: approvalActions,
  );
}
