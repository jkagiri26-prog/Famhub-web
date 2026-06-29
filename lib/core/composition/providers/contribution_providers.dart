/// ============================================================
/// CONTRIBUTION PROVIDERS (PHASE C — RUNTIME CONTRIBUTION ENGINE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/providers/ = composition providers
///
/// ✅ Responsibilities:
///   - Expose the RuntimeContributionEngine via Riverpod providers
///   - Provide access to all 21 contribution types as reactive providers
///   - Enable UI components to watch contribution data
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Reuses existing enabledRuntimeModulesProvider for governance
///   - Contributions filtered by enabled module state
///   - No hardcoded module references
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/providers/composition_providers.dart';
import 'package:famhub_app/core/composition/contributions/runtime_contribution_engine.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';

/// ============================================================
/// CONTRIBUTION ENGINE PROVIDER
/// ============================================================
final runtimeContributionEngineProvider = Provider<RuntimeContributionEngine>((
  ref,
) {
  return RuntimeContributionEngine();
});

// ════════════════════════════════════════════════════════════════
// DASHBOARD CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// Dashboard widgets grouped by section from enabled modules
final dashboardWidgetContributionProvider =
    FutureProvider<Map<String, List<DashboardWidgetContribution>>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.dashboardWidgets(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// HOME SCREEN CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All home screen contributions composed from enabled modules
final homeCompositionProvider = FutureProvider<HomeComposition>((ref) async {
  final engine = ref.read(runtimeContributionEngineProvider);
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return engine.homeComposition(enabledModules: modules);
});

/// Home widgets of a specific type (e.g., 'greeting', 'alert', 'news')
final homeWidgetByTypeProvider =
    FutureProvider.family<List<HomeWidgetContribution>, String>((
      ref,
      type,
    ) async {
      final composition = await ref.watch(homeCompositionProvider.future);
      return composition.ofType(type);
    });

// ════════════════════════════════════════════════════════════════
// QUICK ACTION CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All quick actions from enabled modules, sorted and filtered
final quickActionContributionProvider =
    FutureProvider<List<QuickActionContribution>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.quickActions(enabledModules: modules);
    });

/// Primary quick actions only
final primaryQuickActionsProvider =
    FutureProvider<List<QuickActionContribution>>((ref) async {
      final all = await ref.watch(quickActionContributionProvider.future);
      return all.where((a) => a.isPrimary).toList();
    });

// ════════════════════════════════════════════════════════════════
// ROUTE CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All routes from enabled modules
final routeContributionProvider = FutureProvider<List<RouteContribution>>((
  ref,
) async {
  final engine = ref.read(runtimeContributionEngineProvider);
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return engine.routes(enabledModules: modules);
});

/// Primary routes only (entry points for each module)
final primaryRouteContributionProvider =
    FutureProvider<List<RouteContribution>>((ref) async {
      final all = await ref.watch(routeContributionProvider.future);
      return all.where((r) => r.isPrimary).toList();
    });

// ════════════════════════════════════════════════════════════════
// NOTIFICATION PROVIDER CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All notification providers from enabled modules
final notificationProviderContributionProvider =
    FutureProvider<List<NotificationProviderContribution>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.notificationProviders(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// SEARCH PROVIDER CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All search providers from enabled modules
final searchProviderContributionProvider =
    FutureProvider<List<SearchProviderContribution>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.searchProviders(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// ANALYTICS PROVIDER CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All analytics providers from enabled modules
final analyticsProviderContributionProvider =
    FutureProvider<List<AnalyticsProviderContribution>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.analyticsProviders(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// AI PROVIDER CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All AI providers from enabled modules
final aiProviderContributionProvider =
    FutureProvider<List<AIProviderContribution>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.aiProviders(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// COMMAND PALETTE CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All command palette actions from enabled modules, grouped by category
final commandPaletteActionContributionProvider =
    FutureProvider<Map<String, List<CommandPaletteActionContribution>>>((
      ref,
    ) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.commandPaletteActions(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// BACKGROUND JOB CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All background jobs from enabled modules
final backgroundJobContributionProvider =
    FutureProvider<List<BackgroundJobContribution>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.backgroundJobs(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// SETTINGS PAGE CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All settings pages from enabled modules, grouped by category
final settingsPageContributionProvider =
    FutureProvider<Map<String, List<SettingsPageContribution>>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.settingsPages(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// REPORT CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All reports from enabled modules, grouped by category
final reportContributionProvider =
    FutureProvider<Map<String, List<ReportContribution>>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.reports(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// EXPORT / IMPORT PROVIDER CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All export providers from enabled modules
final exportProviderContributionProvider =
    FutureProvider<List<ExportProviderContribution>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.exportProviders(enabledModules: modules);
    });

/// All import providers from enabled modules
final importProviderContributionProvider =
    FutureProvider<List<ImportProviderContribution>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.importProviders(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// ACTIVITY TIMELINE CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All activity timeline items from enabled modules, grouped by category
final activityTimelineContributionProvider =
    FutureProvider<Map<String, List<ActivityTimelineItemContribution>>>((
      ref,
    ) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.activityTimelineItems(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// HELP ARTICLE CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All help articles from enabled modules
final helpArticleContributionProvider =
    FutureProvider<List<HelpArticleContribution>>((ref) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.helpArticles(enabledModules: modules);
    });

// ════════════════════════════════════════════════════════════════
// CONTEXT MENU CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// Context menu actions for a specific entity type
final contextMenuContributionProvider =
    FutureProvider.family<List<ContextMenuContribution>, String>((
      ref,
      entityType,
    ) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.contextMenus(
        enabledModules: modules,
        entityType: entityType,
      );
    });

// ════════════════════════════════════════════════════════════════
// ENTITY ACTION CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// Entity actions for a specific entity type
final entityActionContributionProvider =
    FutureProvider.family<List<EntityActionContribution>, String>((
      ref,
      entityType,
    ) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.entityActions(
        enabledModules: modules,
        entityType: entityType,
      );
    });

// ════════════════════════════════════════════════════════════════
// WORKFLOW STEP CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// Workflow steps for a specific workflow
final workflowStepContributionProvider =
    FutureProvider.family<List<WorkflowStepContribution>, String>((
      ref,
      workflowKey,
    ) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.workflowSteps(
        enabledModules: modules,
        workflowKey: workflowKey,
      );
    });

// ════════════════════════════════════════════════════════════════
// APPROVAL ACTION CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// Approval actions for a specific entity type
final approvalActionContributionProvider =
    FutureProvider.family<List<ApprovalActionContribution>, String>((
      ref,
      entityType,
    ) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.approvalActions(
        enabledModules: modules,
        entityType: entityType,
      );
    });

// ════════════════════════════════════════════════════════════════
// MODULE-LEVEL CONTRIBUTION PROVIDERS
// ════════════════════════════════════════════════════════════════

/// All contributions for a specific module
final moduleContributionsProvider =
    FutureProvider.family<ModuleContributions, String>((ref, moduleId) async {
      final engine = ref.read(runtimeContributionEngineProvider);
      final modules = await ref.watch(enabledRuntimeModulesProvider.future);
      return engine.allContributionsFor(
        moduleId: moduleId,
        enabledModules: modules,
      );
    });
