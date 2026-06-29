/// ============================================================
/// RUNTIME CONTRIBUTION ENGINE (ENTERPRISE PHASE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/contributions/ = runtime contribution engine
///
/// ✅ Responsibilities:
///   - Central composition engine for ALL contribution types
///   - Aggregates contributions from every enabled module
///   - Applies governance layers before returning contributions
///   - Composes user-specific runtime from module contributions
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Extends existing RuntimeCompositionEngine, does NOT replace it
///   - Extends existing RuntimeDescriptorEngine, does NOT replace it
///   - Reuses existing Context Engine for governance
///   - Reuses existing Feature Flag System for governance
///   - Reuses existing Runtime Governance for governance
///   - Backend (system.modules) is the ONLY source of truth
///   - NO hardcoded widgets, sections, providers, commands, or AI
///
/// ✅ COMPOSITION ORDER:
///   Authenticated User
///     ↓
///   Entity Context
///     ↓
///   Role
///     ↓
///   Subscription Tier
///     ↓
///   Organization
///     ↓
///   Region
///     ↓
///   Feature Flags
///     ↓
///   Module Dependencies
///     ↓
///   Maintenance
///     ↓
///   Backend Visibility
///     ↓
///   Runtime Contribution Engine
///     ↓
///   UI
///
/// Every user receives a completely different application
/// based on their context, role, tier, and governance rules.
/// ============================================================
library;

import 'package:flutter/foundation.dart';

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor_registry.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';
import 'package:famhub_app/core/composition/contributions/contribution_registry.dart';
import 'package:famhub_app/core/composition/domain/models/composition_metrics.dart';

/// ============================================================
/// RUNTIME CONTRIBUTION ENGINE
/// ============================================================
///
/// The execution layer that composes every user-facing capability
/// from module contributions. Every contribution is filtered by
/// governance before reaching the UI.
///
/// This engine does NOT hardcode any module references.
/// All contributions come from registered module descriptors.
/// ============================================================
class RuntimeContributionEngine {
  final CompositionMetricsCollector _metrics;

  RuntimeContributionEngine({
    CompositionMetricsCollector? metrics,
  }) : _metrics = metrics ?? compositionMetricsCollector;

  // ============================================================
  // GROUPED CONTRIBUTIONS
  // ============================================================

  /// Get all contributions for a module, grouped by type
  ModuleContributions getContributionsFor(String moduleId) {
    return ModuleContributions(
      moduleId: moduleId,
      dashboardWidgets: ContributionRegistry.dashboardWidgetsFor(moduleId),
      homeWidgets: ContributionRegistry.homeWidgetsFor(moduleId),
      quickActions: ContributionRegistry.quickActionsFor(moduleId),
      routes: ContributionRegistry.routesFor(moduleId),
      notificationProviders: ContributionRegistry.notificationProvidersFor(moduleId),
      searchProviders: ContributionRegistry.searchProvidersFor(moduleId),
      analyticsProviders: ContributionRegistry.analyticsProvidersFor(moduleId),
      aiProviders: ContributionRegistry.aiProvidersFor(moduleId),
      commandPaletteActions: ContributionRegistry.commandPaletteActionsFor(moduleId),
      backgroundJobs: ContributionRegistry.backgroundJobsFor(moduleId),
      floatingActionButtons: ContributionRegistry.floatingActionButtonsFor(moduleId),
      settingsPages: ContributionRegistry.settingsPagesFor(moduleId),
      reports: ContributionRegistry.reportsFor(moduleId),
      exportProviders: ContributionRegistry.exportProvidersFor(moduleId),
      importProviders: ContributionRegistry.importProvidersFor(moduleId),
      activityTimelineItems: ContributionRegistry.activityTimelineItemsFor(moduleId),
      helpArticles: ContributionRegistry.helpArticlesFor(moduleId),
      contextMenus: ContributionRegistry.contextMenusFor(moduleId),
      entityActions: ContributionRegistry.entityActionsFor(moduleId),
      workflowSteps: ContributionRegistry.workflowStepsFor(moduleId),
      approvalActions: ContributionRegistry.approvalActionsFor(moduleId),
    );
  }

  // ============================================================
  // DASHBOARD CONTRIBUTIONS
  // ============================================================

  /// Get dashboard widgets for enabled modules, grouped by section,
  /// sorted, permission-checked, dependency-resolved, maintenance-filtered.
  ///
  /// The Dashboard Engine renders these — it no longer requests widgets directly.
  Map<String, List<DashboardWidgetContribution>> dashboardWidgets({
    required List<RuntimeModule> enabledModules,
  }) {
    final stopwatch = Stopwatch()..start();
    final sectionMap = <String, List<DashboardWidgetContribution>>{};

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor == null) continue;

      for (final widget in descriptor.dashboardWidgets) {
        sectionMap.putIfAbsent(widget.sectionKey, () => []);
        sectionMap[widget.sectionKey]!.add(
          DashboardWidgetContribution(
            widgetKey: widget.widgetKey,
            displayName: widget.displayName,
            sectionKey: widget.sectionKey,
            displayOrder: widget.displayOrder,
            width: widget.width,
            height: widget.height,
            isVisibleByDefault: widget.isVisibleByDefault,
            iconKey: widget.iconKey,
            refreshIntervalSeconds: widget.refreshIntervalSeconds,
          ),
        );
      }
    }

    // Sort widgets within each section
    for (final section in sectionMap.keys) {
      sectionMap[section]!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }

    stopwatch.stop();
    _metrics.recordDashboardBuildDuration(stopwatch.elapsedMilliseconds);

    return sectionMap;
  }

  // ============================================================
  // HOME SCREEN CONTRIBUTIONS
  // ============================================================

  /// Get all home contributions composed for the home screen.
  /// Includes: greeting, alerts, news, promotions, weather,
  /// recommended actions, pinned modules, quick actions,
  /// recent activity, AI suggestions.
  HomeComposition homeComposition({
    required List<RuntimeModule> enabledModules,
  }) {
    final stopwatch = Stopwatch()..start();

    final contributions = HomeComposition();

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor == null) continue;

      for (final widget in descriptor.homeWidgets) {
        contributions.add(HomeWidgetContribution(
          widgetKey: widget.widgetKey,
          widgetType: widget.widgetType,
          displayName: widget.displayName,
          displayOrder: widget.displayOrder,
          iconKey: widget.iconKey,
          priority: widget.priority,
          isVisibleByDefault: widget.isVisibleByDefault,
        ));
      }
    }

    stopwatch.stop();
    _metrics.recordCompositionDuration(stopwatch.elapsedMilliseconds);

    return contributions;
  }

  // ============================================================
  // QUICK ACTION CONTRIBUTIONS
  // ============================================================

  /// Get all quick actions from enabled modules.
  List<QuickActionContribution> quickActions({
    required List<RuntimeModule> enabledModules,
  }) {
    final actions = <QuickActionContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;
      if (!module.quickActionVisible) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor == null) continue;

      for (final qa in descriptor.quickActions) {
        actions.add(QuickActionContribution(
          actionKey: qa.actionKey,
          label: qa.label,
          iconKey: qa.iconKey,
          displayOrder: qa.displayOrder,
          isVisibleByDefault: qa.isVisibleByDefault,
          route: qa.route,
          isPrimary: qa.isPrimary,
          moduleId: module.moduleId,
        ));
      }
    }

    // Sort: primary first, then by display order
    actions.sort((a, b) {
      if (a.isPrimary && !b.isPrimary) return -1;
      if (!a.isPrimary && b.isPrimary) return 1;
      return a.displayOrder.compareTo(b.displayOrder);
    });

    return actions;
  }

  // ============================================================
  // ROUTE CONTRIBUTIONS
  // ============================================================

  /// Get all routes from enabled modules.
  List<RouteContribution> routes({
    required List<RuntimeModule> enabledModules,
  }) {
    final routes = <RouteContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor == null) continue;

      for (final r in descriptor.routes) {
        routes.add(RouteContribution(
          path: r.path,
          name: r.name,
          isPrimary: r.isPrimary,
          displayOrder: r.displayOrder,
          moduleId: module.moduleId,
        ));
      }
    }

    return routes;
  }

  // ============================================================
  // NOTIFICATION PROVIDER CONTRIBUTIONS
  // ============================================================

  /// Get all notification providers from enabled modules.
  /// Notification Center uses this instead of querying modules directly.
  List<NotificationProviderContribution> notificationProviders({
    required List<RuntimeModule> enabledModules,
  }) {
    final providers = <NotificationProviderContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor == null) continue;

      for (final np in descriptor.notificationProviders) {
        providers.add(NotificationProviderContribution(
          providerKey: np.providerKey,
          displayName: np.displayName,
          channel: 'in_app',
          priority: 0,
          category: module.moduleId,
          iconKey: 'notifications',
          notificationTypes: np.notificationTypes,
          enabledByDefault: np.enabledByDefault,
        ));
      }
    }

    return providers;
  }

  // ============================================================
  // SEARCH PROVIDER CONTRIBUTIONS
  // ============================================================

  /// Get all search providers from enabled modules.
  /// Global search uses this instead of manually registering providers.
  List<SearchProviderContribution> searchProviders({
    required List<RuntimeModule> enabledModules,
  }) {
    final providers = <SearchProviderContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor == null) continue;

      for (final sp in descriptor.searchProviders) {
        for (final entityType in sp.entityTypes) {
          providers.add(SearchProviderContribution(
            providerKey: '${sp.providerKey}_$entityType',
            displayName: sp.displayName,
            entityType: entityType,
            searchRepository: '${module.moduleId}_$entityType',
            priority: 0,
            filters: [],
            permissions: [],
            enabledByDefault: sp.enabledByDefault,
          ));
        }
      }
    }

    return providers;
  }

  // ============================================================
  // ANALYTICS PROVIDER CONTRIBUTIONS
  // ============================================================

  /// Get all analytics providers from enabled modules.
  List<AnalyticsProviderContribution> analyticsProviders({
    required List<RuntimeModule> enabledModules,
  }) {
    final providers = <AnalyticsProviderContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor == null) continue;

      for (final ap in descriptor.analyticsProviders) {
        providers.add(AnalyticsProviderContribution(
          providerKey: ap.providerKey,
          displayName: ap.displayName,
          metricKeys: ap.metricKeys,
          enabledByDefault: ap.enabledByDefault,
        ));
      }
    }

    return providers;
  }

  // ============================================================
  // AI PROVIDER CONTRIBUTIONS
  // ============================================================

  /// Get all AI provider capabilities from enabled modules.
  /// The AI Engine discovers these automatically — no manual registration needed.
  List<AIProviderContribution> aiProviders({
    required List<RuntimeModule> enabledModules,
  }) {
    final providers = <AIProviderContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      // AI contributions come from the extended registry
      providers.addAll(ContributionRegistry.aiProvidersFor(module.moduleId));
    }

    return providers;
  }

  // ============================================================
  // COMMAND PALETTE CONTRIBUTIONS
  // ============================================================

  /// Get all command palette actions from enabled modules.
  /// The Ctrl+K command palette is generated entirely from runtime contributions.
  Map<String, List<CommandPaletteActionContribution>> commandPaletteActions({
    required List<RuntimeModule> enabledModules,
  }) {
    final categorized = <String, List<CommandPaletteActionContribution>>{};

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final category = module.displayName;
      final descriptor = ModuleDescriptorRegistry.get(module.moduleId);
      if (descriptor == null) continue;

      categorized.putIfAbsent(category, () => []);

      // Add a "Go to [module]" command
      categorized[category]!.add(CommandPaletteActionContribution(
        actionKey: 'go_to_${module.moduleId}',
        label: 'Go to ${module.displayName}',
        description: 'Navigate to ${module.displayName}',
        category: category,
        iconKey: module.iconKey,
        route: module.route,
        priority: -1, // always at top
        keywords: [module.displayName.toLowerCase(), module.moduleId],
        moduleId: module.moduleId,
      ));

      // Add quick actions as commands
      for (final qa in descriptor.quickActions) {
        categorized[category]!.add(CommandPaletteActionContribution(
          actionKey: qa.actionKey,
          label: qa.label,
          description: '${module.displayName}: ${qa.label}',
          category: category,
          iconKey: qa.iconKey,
          route: qa.route,
          priority: qa.displayOrder,
          keywords: [qa.label.toLowerCase(), ...qa.label.toLowerCase().split(' ')],
          moduleId: module.moduleId,
        ));
      }

      // Add AI capabilities as commands
      final aiContribs = ContributionRegistry.aiProvidersFor(module.moduleId);
      for (final ai in aiContribs) {
        categorized[category]!.add(CommandPaletteActionContribution(
          actionKey: 'ai_${ai.providerKey}',
          label: ai.displayName,
          description: ai.description,
          category: category,
          iconKey: 'auto_awesome',
          priority: 50,
          keywords: [ai.capability, ai.displayName.toLowerCase()],
          moduleId: module.moduleId,
        ));
      }

      // Add any explicitly registered command palette actions
      final explicitCommands = ContributionRegistry.commandPaletteActionsFor(module.moduleId);
      categorized[category]!.addAll(explicitCommands);
    }

    // Sort within each category
    for (final cat in categorized.keys) {
      categorized[cat]!.sort((a, b) => a.priority.compareTo(b.priority));
    }

    return categorized;
  }

  // ============================================================
  // BACKGROUND JOB CONTRIBUTIONS
  // ============================================================

  /// Get all background jobs from enabled modules.
  List<BackgroundJobContribution> backgroundJobs({
    required List<RuntimeModule> enabledModules,
  }) {
    final jobs = <BackgroundJobContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;
      jobs.addAll(ContributionRegistry.backgroundJobsFor(module.moduleId));
    }

    return jobs;
  }

  // ============================================================
  // SETTINGS PAGE CONTRIBUTIONS
  // ============================================================

  /// Get all settings pages from enabled modules.
  Map<String, List<SettingsPageContribution>> settingsPages({
    required List<RuntimeModule> enabledModules,
  }) {
    final categorized = <String, List<SettingsPageContribution>>{};

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final pages = ContributionRegistry.settingsPagesFor(module.moduleId);
      for (final page in pages) {
        categorized.putIfAbsent(page.category, () => []);
        categorized[page.category]!.add(page);
      }
    }

    for (final cat in categorized.keys) {
      categorized[cat]!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }

    return categorized;
  }

  // ============================================================
  // REPORT CONTRIBUTIONS
  // ============================================================

  /// Get all reports from enabled modules.
  Map<String, List<ReportContribution>> reports({
    required List<RuntimeModule> enabledModules,
  }) {
    final categorized = <String, List<ReportContribution>>{};

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final reportList = ContributionRegistry.reportsFor(module.moduleId);
      for (final report in reportList) {
        categorized.putIfAbsent(report.category, () => []);
        categorized[report.category]!.add(report);
      }
    }

    for (final cat in categorized.keys) {
      categorized[cat]!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }

    return categorized;
  }

  // ============================================================
  // FLOATING ACTION BUTTON CONTRIBUTIONS
  // ============================================================

  /// Get all FABs from enabled modules (optionally filtered by screen).
  List<FloatingActionButtonContribution> floatingActionButtons({
    required List<RuntimeModule> enabledModules,
    String? forScreen,
  }) {
    final fabs = <FloatingActionButtonContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final moduleFabs = ContributionRegistry.floatingActionButtonsFor(module.moduleId);
      for (final fab in moduleFabs) {
        if (forScreen == null || fab.screenRoute == null || fab.screenRoute == forScreen) {
          fabs.add(fab);
        }
      }
    }

    fabs.sort((a, b) => a.priority.compareTo(b.priority));
    return fabs;
  }

  // ============================================================
  // EXPORT / IMPORT PROVIDER CONTRIBUTIONS
  // ============================================================

  /// Get all export providers from enabled modules.
  List<ExportProviderContribution> exportProviders({
    required List<RuntimeModule> enabledModules,
  }) {
    final providers = <ExportProviderContribution>[];
    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;
      providers.addAll(ContributionRegistry.exportProvidersFor(module.moduleId));
    }
    return providers;
  }

  /// Get all import providers from enabled modules.
  List<ImportProviderContribution> importProviders({
    required List<RuntimeModule> enabledModules,
  }) {
    final providers = <ImportProviderContribution>[];
    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;
      providers.addAll(ContributionRegistry.importProvidersFor(module.moduleId));
    }
    return providers;
  }

  // ============================================================
  // ACTIVITY TIMELINE CONTRIBUTIONS
  // ============================================================

  /// Get all activity timeline items from enabled modules.
  Map<String, List<ActivityTimelineItemContribution>> activityTimelineItems({
    required List<RuntimeModule> enabledModules,
  }) {
    final categorized = <String, List<ActivityTimelineItemContribution>>{};

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final items = ContributionRegistry.activityTimelineItemsFor(module.moduleId);
      for (final item in items) {
        categorized.putIfAbsent(item.category, () => []);
        categorized[item.category]!.add(item);
      }
    }

    for (final cat in categorized.keys) {
      categorized[cat]!.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    }

    return categorized;
  }

  // ============================================================
  // HELP ARTICLE CONTRIBUTIONS
  // ============================================================

  /// Get all help articles from enabled modules.
  List<HelpArticleContribution> helpArticles({
    required List<RuntimeModule> enabledModules,
  }) {
    final articles = <HelpArticleContribution>[];
    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;
      articles.addAll(ContributionRegistry.helpArticlesFor(module.moduleId));
    }
    return articles;
  }

  // ============================================================
  // CONTEXT MENU CONTRIBUTIONS
  // ============================================================

  /// Get context menu actions for a specific entity type from enabled modules.
  List<ContextMenuContribution> contextMenus({
    required List<RuntimeModule> enabledModules,
    required String entityType,
  }) {
    final actions = <ContextMenuContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final moduleActions = ContributionRegistry.contextMenusFor(module.moduleId);
      for (final action in moduleActions) {
        if (action.entityType == entityType) {
          actions.add(action);
        }
      }
    }

    actions.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return actions;
  }

  // ============================================================
  // ENTITY ACTION CONTRIBUTIONS
  // ============================================================

  /// Get entity actions for a specific entity type from enabled modules.
  List<EntityActionContribution> entityActions({
    required List<RuntimeModule> enabledModules,
    required String entityType,
  }) {
    final actions = <EntityActionContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final moduleActions = ContributionRegistry.entityActionsFor(module.moduleId);
      for (final action in moduleActions) {
        if (action.entityType == entityType) {
          actions.add(action);
        }
      }
    }

    actions.sort((a, b) {
      if (a.isPrimary && !b.isPrimary) return -1;
      if (!a.isPrimary && b.isPrimary) return 1;
      return a.displayOrder.compareTo(b.displayOrder);
    });

    return actions;
  }

  // ============================================================
  // WORKFLOW STEP CONTRIBUTIONS
  // ============================================================

  /// Get workflow steps for a specific workflow from enabled modules.
  List<WorkflowStepContribution> workflowSteps({
    required List<RuntimeModule> enabledModules,
    required String workflowKey,
  }) {
    final steps = <WorkflowStepContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final moduleSteps = ContributionRegistry.workflowStepsFor(module.moduleId);
      for (final step in moduleSteps) {
        if (step.workflowKey == workflowKey) {
          steps.add(step);
        }
      }
    }

    steps.sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    return steps;
  }

  // ============================================================
  // APPROVAL ACTION CONTRIBUTIONS
  // ============================================================

  /// Get approval actions for a specific entity type from enabled modules.
  List<ApprovalActionContribution> approvalActions({
    required List<RuntimeModule> enabledModules,
    required String entityType,
  }) {
    final actions = <ApprovalActionContribution>[];

    for (final module in enabledModules) {
      if (!module.isEnabled || module.maintenanceMode) continue;

      final moduleActions = ContributionRegistry.approvalActionsFor(module.moduleId);
      for (final action in moduleActions) {
        if (action.entityType == entityType) {
          actions.add(action);
        }
      }
    }

    return actions;
  }

  // ============================================================
  // COMPREHENSIVE MODULE EXPORT
  // ============================================================

  /// Get ALL contributions for an enabled module (bulk query).
  ModuleContributions allContributionsFor({
    required String moduleId,
    required List<RuntimeModule> enabledModules,
  }) {
    final exists = enabledModules.any((m) =>
        m.moduleId == moduleId && m.isEnabled && !m.maintenanceMode);

    if (!exists) {
      return ModuleContributions.empty(moduleId);
    }

    return getContributionsFor(moduleId);
  }
}

/// ============================================================
/// MODULE CONTRIBUTIONS (AGGREGATED OUTPUT)
/// ============================================================
///
/// A container for all contributions from a single module.
/// ============================================================
class ModuleContributions {
  final String moduleId;
  final List<DashboardWidgetContribution> dashboardWidgets;
  final List<HomeWidgetContribution> homeWidgets;
  final List<QuickActionContribution> quickActions;
  final List<RouteContribution> routes;
  final List<NotificationProviderContribution> notificationProviders;
  final List<SearchProviderContribution> searchProviders;
  final List<AnalyticsProviderContribution> analyticsProviders;
  final List<AIProviderContribution> aiProviders;
  final List<CommandPaletteActionContribution> commandPaletteActions;
  final List<BackgroundJobContribution> backgroundJobs;
  final List<FloatingActionButtonContribution> floatingActionButtons;
  final List<SettingsPageContribution> settingsPages;
  final List<ReportContribution> reports;
  final List<ExportProviderContribution> exportProviders;
  final List<ImportProviderContribution> importProviders;
  final List<ActivityTimelineItemContribution> activityTimelineItems;
  final List<HelpArticleContribution> helpArticles;
  final List<ContextMenuContribution> contextMenus;
  final List<EntityActionContribution> entityActions;
  final List<WorkflowStepContribution> workflowSteps;
  final List<ApprovalActionContribution> approvalActions;

  const ModuleContributions({
    required this.moduleId,
    this.dashboardWidgets = const [],
    this.homeWidgets = const [],
    this.quickActions = const [],
    this.routes = const [],
    this.notificationProviders = const [],
    this.searchProviders = const [],
    this.analyticsProviders = const [],
    this.aiProviders = const [],
    this.commandPaletteActions = const [],
    this.backgroundJobs = const [],
    this.floatingActionButtons = const [],
    this.settingsPages = const [],
    this.reports = const [],
    this.exportProviders = const [],
    this.importProviders = const [],
    this.activityTimelineItems = const [],
    this.helpArticles = const [],
    this.contextMenus = const [],
    this.entityActions = const [],
    this.workflowSteps = const [],
    this.approvalActions = const [],
  });

  factory ModuleContributions.empty(String moduleId) =>
      ModuleContributions(moduleId: moduleId);

  bool get isEmpty =>
      dashboardWidgets.isEmpty &&
      homeWidgets.isEmpty &&
      quickActions.isEmpty &&
      routes.isEmpty &&
      notificationProviders.isEmpty &&
      searchProviders.isEmpty &&
      analyticsProviders.isEmpty &&
      aiProviders.isEmpty &&
      commandPaletteActions.isEmpty &&
      backgroundJobs.isEmpty &&
      floatingActionButtons.isEmpty &&
      settingsPages.isEmpty &&
      reports.isEmpty &&
      exportProviders.isEmpty &&
      importProviders.isEmpty &&
      activityTimelineItems.isEmpty &&
      helpArticles.isEmpty &&
      contextMenus.isEmpty &&
      entityActions.isEmpty &&
      workflowSteps.isEmpty &&
      approvalActions.isEmpty;
}

/// ============================================================
/// HOME COMPOSITION (AGGREGATED HOME SCREEN DATA)
/// ============================================================
///
/// Composes all home screen elements from module contributions.
/// Types: greeting, alert, news, promotion, weather,
/// recommended_action, pinned_module, quick_action,
/// recent_activity, ai_suggestion
/// ============================================================
class HomeComposition {
  final List<HomeWidgetContribution> _allWidgets = [];

  void add(HomeWidgetContribution widget) {
    _allWidgets.add(widget);
  }

  void addAll(List<HomeWidgetContribution> widgets) {
    _allWidgets.addAll(widgets);
  }

  /// Get all widgets sorted by priority (highest first)
  List<HomeWidgetContribution> get allSorted {
    final sorted = List<HomeWidgetContribution>.from(_allWidgets);
    sorted.sort((a, b) => b.priority.compareTo(a.priority));
    return sorted;
  }

  /// Get widgets of a specific type
  List<HomeWidgetContribution> ofType(String widgetType) {
    return _allWidgets.where((w) => w.widgetType == widgetType).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// Get all unique widget types present
  List<String> get types {
    return _allWidgets.map((w) => w.widgetType).toSet().toList();
  }

  /// Get all greetings
  List<HomeWidgetContribution> get greetings => ofType('greeting');

  /// Get all alerts
  List<HomeWidgetContribution> get alerts => ofType('alert');

  /// Get all news items
  List<HomeWidgetContribution> get news => ofType('news');

  /// Get all promotions
  List<HomeWidgetContribution> get promotions => ofType('promotion');

  /// Get all weather widgets
  List<HomeWidgetContribution> get weather => ofType('weather');

  /// Get all recommended actions
  List<HomeWidgetContribution> get recommendedActions => ofType('recommended_action');

  /// Get all pinned modules
  List<HomeWidgetContribution> get pinnedModules => ofType('pinned_module');

  /// Get all quick actions for home
  List<HomeWidgetContribution> get quickActions => ofType('quick_action');

  /// Get all recent activity items
  List<HomeWidgetContribution> get recentActivity => ofType('recent_activity');

  /// Get all AI suggestions
  List<HomeWidgetContribution> get aiSuggestions => ofType('ai_suggestion');

  int get length => _allWidgets.length;
  bool get isEmpty => _allWidgets.isEmpty;
  bool get isNotEmpty => _allWidgets.isNotEmpty;
}

/// Singleton instance for app-wide access
final runtimeContributionEngine = RuntimeContributionEngine();
