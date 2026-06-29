/// ============================================================
/// CONTRIBUTION REGISTRY (RUNTIME CONTRIBUTION ENGINE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/contributions/ = runtime contribution engine
///
/// ✅ Responsibilities:
///   - Central registry for all module contributions
///   - Module descriptors register their contributions here
///   - The Contribution Engine queries this registry
///   - Supports hot-reload by allowing overwrite
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - NO hardcoded contributions
///   - NO hardcoded module references
///   - Reuses existing ModuleDescriptorRegistry as the metadata layer
///   - This registry is the runtime expansion of descriptor metadata
/// ============================================================
library;

import 'package:famhub_app/core/composition/contributions/contribution_models.dart';

/// ============================================================
/// CONTRIBUTION REGISTRY
/// ============================================================
///
/// Each module registers its full set of contributions here.
/// The registry aggregates all contributions from all modules.
///
/// Usage:
///   ContributionRegistry.registerMarketplaceContributions(...);
///   ContributionRegistry.registerFarmContributions(...);
///
/// Then query:
///   ContributionRegistry.allDashboardWidgets();
///   ContributionRegistry.allCommandPaletteActions();
/// ============================================================
class ContributionRegistry {
  // ── Dashboard Widgets ──
  static final Map<String, List<DashboardWidgetContribution>> _dashboardWidgets = {};

  // ── Home Widgets ──
  static final Map<String, List<HomeWidgetContribution>> _homeWidgets = {};

  // ── Quick Actions ──
  static final Map<String, List<QuickActionContribution>> _quickActions = {};

  // ── Routes ──
  static final Map<String, List<RouteContribution>> _routes = {};

  // ── Notification Providers ──
  static final Map<String, List<NotificationProviderContribution>> _notificationProviders = {};

  // ── Search Providers ──
  static final Map<String, List<SearchProviderContribution>> _searchProviders = {};

  // ── Analytics Providers ──
  static final Map<String, List<AnalyticsProviderContribution>> _analyticsProviders = {};

  // ── AI Providers ──
  static final Map<String, List<AIProviderContribution>> _aiProviders = {};

  // ── Command Palette Actions ──
  static final Map<String, List<CommandPaletteActionContribution>> _commandPaletteActions = {};

  // ── Background Jobs ──
  static final Map<String, List<BackgroundJobContribution>> _backgroundJobs = {};

  // ── Floating Action Buttons ──
  static final Map<String, List<FloatingActionButtonContribution>> _floatingActionButtons = {};

  // ── Settings Pages ──
  static final Map<String, List<SettingsPageContribution>> _settingsPages = {};

  // ── Reports ──
  static final Map<String, List<ReportContribution>> _reports = {};

  // ── Export Providers ──
  static final Map<String, List<ExportProviderContribution>> _exportProviders = {};

  // ── Import Providers ──
  static final Map<String, List<ImportProviderContribution>> _importProviders = {};

  // ── Activity Timeline Items ──
  static final Map<String, List<ActivityTimelineItemContribution>> _activityTimelineItems = {};

  // ── Help Articles ──
  static final Map<String, List<HelpArticleContribution>> _helpArticles = {};

  // ── Context Menus ──
  static final Map<String, List<ContextMenuContribution>> _contextMenus = {};

  // ── Entity Actions ──
  static final Map<String, List<EntityActionContribution>> _entityActions = {};

  // ── Workflow Steps ──
  static final Map<String, List<WorkflowStepContribution>> _workflowSteps = {};

  // ── Approval Actions ──
  static final Map<String, List<ApprovalActionContribution>> _approvalActions = {};

  // ============================================================
  // REGISTRATION METHODS
  // ============================================================

  /// Register all contributions for a module
  static void registerModule({
    required String moduleId,
    List<DashboardWidgetContribution> dashboardWidgets = const [],
    List<HomeWidgetContribution> homeWidgets = const [],
    List<QuickActionContribution> quickActions = const [],
    List<RouteContribution> routes = const [],
    List<NotificationProviderContribution> notificationProviders = const [],
    List<SearchProviderContribution> searchProviders = const [],
    List<AnalyticsProviderContribution> analyticsProviders = const [],
    List<AIProviderContribution> aiProviders = const [],
    List<CommandPaletteActionContribution> commandPaletteActions = const [],
    List<BackgroundJobContribution> backgroundJobs = const [],
    List<FloatingActionButtonContribution> floatingActionButtons = const [],
    List<SettingsPageContribution> settingsPages = const [],
    List<ReportContribution> reports = const [],
    List<ExportProviderContribution> exportProviders = const [],
    List<ImportProviderContribution> importProviders = const [],
    List<ActivityTimelineItemContribution> activityTimelineItems = const [],
    List<HelpArticleContribution> helpArticles = const [],
    List<ContextMenuContribution> contextMenus = const [],
    List<EntityActionContribution> entityActions = const [],
    List<WorkflowStepContribution> workflowSteps = const [],
    List<ApprovalActionContribution> approvalActions = const [],
  }) {
    _registerList(_dashboardWidgets, moduleId, dashboardWidgets);
    _registerList(_homeWidgets, moduleId, homeWidgets);
    _registerList(_quickActions, moduleId, quickActions);
    _registerList(_routes, moduleId, routes);
    _registerList(_notificationProviders, moduleId, notificationProviders);
    _registerList(_searchProviders, moduleId, searchProviders);
    _registerList(_analyticsProviders, moduleId, analyticsProviders);
    _registerList(_aiProviders, moduleId, aiProviders);
    _registerList(_commandPaletteActions, moduleId, commandPaletteActions);
    _registerList(_backgroundJobs, moduleId, backgroundJobs);
    _registerList(_floatingActionButtons, moduleId, floatingActionButtons);
    _registerList(_settingsPages, moduleId, settingsPages);
    _registerList(_reports, moduleId, reports);
    _registerList(_exportProviders, moduleId, exportProviders);
    _registerList(_importProviders, moduleId, importProviders);
    _registerList(_activityTimelineItems, moduleId, activityTimelineItems);
    _registerList(_helpArticles, moduleId, helpArticles);
    _registerList(_contextMenus, moduleId, contextMenus);
    _registerList(_entityActions, moduleId, entityActions);
    _registerList(_workflowSteps, moduleId, workflowSteps);
    _registerList(_approvalActions, moduleId, approvalActions);
  }

  static void _registerList<T>(
    Map<String, List<T>> registry,
    String moduleId,
    List<T> items,
  ) {
    if (items.isEmpty) return;
    // Allow overwrite for hot-reload
    registry[moduleId] = items;
  }

  /// Remove all contributions for a module
  static void unregisterModule(String moduleId) {
    _dashboardWidgets.remove(moduleId);
    _homeWidgets.remove(moduleId);
    _quickActions.remove(moduleId);
    _routes.remove(moduleId);
    _notificationProviders.remove(moduleId);
    _searchProviders.remove(moduleId);
    _analyticsProviders.remove(moduleId);
    _aiProviders.remove(moduleId);
    _commandPaletteActions.remove(moduleId);
    _backgroundJobs.remove(moduleId);
    _floatingActionButtons.remove(moduleId);
    _settingsPages.remove(moduleId);
    _reports.remove(moduleId);
    _exportProviders.remove(moduleId);
    _importProviders.remove(moduleId);
    _activityTimelineItems.remove(moduleId);
    _helpArticles.remove(moduleId);
    _contextMenus.remove(moduleId);
    _entityActions.remove(moduleId);
    _workflowSteps.remove(moduleId);
    _approvalActions.remove(moduleId);
  }

  // ============================================================
  // QUERY METHODS (ALL CONTRIBUTIONS ACROSS ALL MODULES)
  // ============================================================

  /// Get all dashboard widgets from all modules
  static List<DashboardWidgetContribution> allDashboardWidgets() {
    return _flattenMap(_dashboardWidgets);
  }

  /// Get all home widgets from all modules
  static List<HomeWidgetContribution> allHomeWidgets() {
    return _flattenMap(_homeWidgets);
  }

  /// Get all quick actions from all modules
  static List<QuickActionContribution> allQuickActions() {
    return _flattenMap(_quickActions);
  }

  /// Get all routes from all modules
  static List<RouteContribution> allRoutes() {
    return _flattenMap(_routes);
  }

  /// Get all notification providers from all modules
  static List<NotificationProviderContribution> allNotificationProviders() {
    return _flattenMap(_notificationProviders);
  }

  /// Get all search providers from all modules
  static List<SearchProviderContribution> allSearchProviders() {
    return _flattenMap(_searchProviders);
  }

  /// Get all analytics providers from all modules
  static List<AnalyticsProviderContribution> allAnalyticsProviders() {
    return _flattenMap(_analyticsProviders);
  }

  /// Get all AI providers from all modules
  static List<AIProviderContribution> allAIProviders() {
    return _flattenMap(_aiProviders);
  }

  /// Get all command palette actions from all modules
  static List<CommandPaletteActionContribution> allCommandPaletteActions() {
    return _flattenMap(_commandPaletteActions);
  }

  /// Get all background jobs from all modules
  static List<BackgroundJobContribution> allBackgroundJobs() {
    return _flattenMap(_backgroundJobs);
  }

  /// Get all floating action buttons from all modules
  static List<FloatingActionButtonContribution> allFloatingActionButtons() {
    return _flattenMap(_floatingActionButtons);
  }

  /// Get all settings pages from all modules
  static List<SettingsPageContribution> allSettingsPages() {
    return _flattenMap(_settingsPages);
  }

  /// Get all reports from all modules
  static List<ReportContribution> allReports() {
    return _flattenMap(_reports);
  }

  /// Get all export providers from all modules
  static List<ExportProviderContribution> allExportProviders() {
    return _flattenMap(_exportProviders);
  }

  /// Get all import providers from all modules
  static List<ImportProviderContribution> allImportProviders() {
    return _flattenMap(_importProviders);
  }

  /// Get all activity timeline items from all modules
  static List<ActivityTimelineItemContribution> allActivityTimelineItems() {
    return _flattenMap(_activityTimelineItems);
  }

  /// Get all help articles from all modules
  static List<HelpArticleContribution> allHelpArticles() {
    return _flattenMap(_helpArticles);
  }

  /// Get all context menus from all modules
  static List<ContextMenuContribution> allContextMenus() {
    return _flattenMap(_contextMenus);
  }

  /// Get all entity actions from all modules
  static List<EntityActionContribution> allEntityActions() {
    return _flattenMap(_entityActions);
  }

  /// Get all workflow steps from all modules
  static List<WorkflowStepContribution> allWorkflowSteps() {
    return _flattenMap(_workflowSteps);
  }

  /// Get all approval actions from all modules
  static List<ApprovalActionContribution> allApprovalActions() {
    return _flattenMap(_approvalActions);
  }

  // ============================================================
  // QUERY METHODS (BY MODULE ID)
  // ============================================================

  static List<DashboardWidgetContribution> dashboardWidgetsFor(String moduleId) {
    return _dashboardWidgets[moduleId] ?? [];
  }

  static List<HomeWidgetContribution> homeWidgetsFor(String moduleId) {
    return _homeWidgets[moduleId] ?? [];
  }

  static List<QuickActionContribution> quickActionsFor(String moduleId) {
    return _quickActions[moduleId] ?? [];
  }

  static List<RouteContribution> routesFor(String moduleId) {
    return _routes[moduleId] ?? [];
  }

  static List<NotificationProviderContribution> notificationProvidersFor(String moduleId) {
    return _notificationProviders[moduleId] ?? [];
  }

  static List<SearchProviderContribution> searchProvidersFor(String moduleId) {
    return _searchProviders[moduleId] ?? [];
  }

  static List<AnalyticsProviderContribution> analyticsProvidersFor(String moduleId) {
    return _analyticsProviders[moduleId] ?? [];
  }

  static List<AIProviderContribution> aiProvidersFor(String moduleId) {
    return _aiProviders[moduleId] ?? [];
  }

  static List<CommandPaletteActionContribution> commandPaletteActionsFor(String moduleId) {
    return _commandPaletteActions[moduleId] ?? [];
  }

  static List<BackgroundJobContribution> backgroundJobsFor(String moduleId) {
    return _backgroundJobs[moduleId] ?? [];
  }

  static List<FloatingActionButtonContribution> floatingActionButtonsFor(String moduleId) {
    return _floatingActionButtons[moduleId] ?? [];
  }

  static List<SettingsPageContribution> settingsPagesFor(String moduleId) {
    return _settingsPages[moduleId] ?? [];
  }

  static List<ReportContribution> reportsFor(String moduleId) {
    return _reports[moduleId] ?? [];
  }

  static List<ExportProviderContribution> exportProvidersFor(String moduleId) {
    return _exportProviders[moduleId] ?? [];
  }

  static List<ImportProviderContribution> importProvidersFor(String moduleId) {
    return _importProviders[moduleId] ?? [];
  }

  static List<ActivityTimelineItemContribution> activityTimelineItemsFor(String moduleId) {
    return _activityTimelineItems[moduleId] ?? [];
  }

  static List<HelpArticleContribution> helpArticlesFor(String moduleId) {
    return _helpArticles[moduleId] ?? [];
  }

  static List<ContextMenuContribution> contextMenusFor(String moduleId) {
    return _contextMenus[moduleId] ?? [];
  }

  static List<EntityActionContribution> entityActionsFor(String moduleId) {
    return _entityActions[moduleId] ?? [];
  }

  static List<WorkflowStepContribution> workflowStepsFor(String moduleId) {
    return _workflowSteps[moduleId] ?? [];
  }

  static List<ApprovalActionContribution> approvalActionsFor(String moduleId) {
    return _approvalActions[moduleId] ?? [];
  }

  // ============================================================
  // UTILITY
  // ============================================================

  static List<T> _flattenMap<T>(Map<String, List<T>> map) {
    final result = <T>[];
    for (final list in map.values) {
      result.addAll(list);
    }
    return result;
  }

  /// Get all module IDs that have contributions registered
  static List<String> get registeredModuleIds {
    final ids = <String>{};
    ids.addAll(_dashboardWidgets.keys);
    ids.addAll(_homeWidgets.keys);
    ids.addAll(_quickActions.keys);
    ids.addAll(_routes.keys);
    ids.addAll(_notificationProviders.keys);
    ids.addAll(_searchProviders.keys);
    ids.addAll(_analyticsProviders.keys);
    ids.addAll(_aiProviders.keys);
    ids.addAll(_commandPaletteActions.keys);
    ids.addAll(_backgroundJobs.keys);
    ids.addAll(_floatingActionButtons.keys);
    ids.addAll(_settingsPages.keys);
    ids.addAll(_reports.keys);
    ids.addAll(_exportProviders.keys);
    ids.addAll(_importProviders.keys);
    ids.addAll(_activityTimelineItems.keys);
    ids.addAll(_helpArticles.keys);
    ids.addAll(_contextMenus.keys);
    ids.addAll(_entityActions.keys);
    ids.addAll(_workflowSteps.keys);
    ids.addAll(_approvalActions.keys);
    return ids.toList();
  }

  /// Check if a module has any contributions
  static bool hasContributions(String moduleId) {
    return registeredModuleIds.contains(moduleId);
  }

  /// Clear all contributions (for testing/hot-reload)
  static void clear() {
    _dashboardWidgets.clear();
    _homeWidgets.clear();
    _quickActions.clear();
    _routes.clear();
    _notificationProviders.clear();
    _searchProviders.clear();
    _analyticsProviders.clear();
    _aiProviders.clear();
    _commandPaletteActions.clear();
    _backgroundJobs.clear();
    _floatingActionButtons.clear();
    _settingsPages.clear();
    _reports.clear();
    _exportProviders.clear();
    _importProviders.clear();
    _activityTimelineItems.clear();
    _helpArticles.clear();
    _contextMenus.clear();
    _entityActions.clear();
    _workflowSteps.clear();
    _approvalActions.clear();
  }
}
