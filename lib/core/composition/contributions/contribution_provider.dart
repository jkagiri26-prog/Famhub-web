/// ============================================================
/// CONTRIBUTION PROVIDERS (RUNTIME CONTRIBUTION ENGINE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/contributions/ = runtime contribution engine
///
/// ✅ Responsibilities:
///   - Wire RuntimeContributionEngine into Riverpod state management
///   - Provide all contribution types as reactive providers
///   - Auto-invalidate on module/context changes
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Extends existing composition providers
///   - Reuses existing enabledRuntimeModulesProvider
///   - No hardcoded module references
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/domain/models/module_descriptor.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';
import 'package:famhub_app/core/composition/contributions/runtime_contribution_engine.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';

// ============================================================
// CONTRIBUTION ENGINE PROVIDER
// ============================================================

final runtimeContributionEngineProvider = Provider<RuntimeContributionEngine>((ref) {
  return runtimeContributionEngine;
});

// ============================================================
// DASHBOARD CONTRIBUTIONS
// ============================================================

/// Dashboard widgets grouped by section — governance-filtered.
/// The Dashboard Engine renders these; it no longer requests widgets directly.
final dashboardContributionProvider = FutureProvider<Map<String, List<DashboardWidgetContribution>>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.dashboardWidgets(enabledModules: modules);
});

// ============================================================
// HOME COMPOSITION CONTRIBUTIONS
// ============================================================

/// Home screen composition — all widgets from all enabled modules.
final homeCompositionProvider = FutureProvider<HomeComposition>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.homeComposition(enabledModules: modules);
});

// ============================================================
// QUICK ACTION CONTRIBUTIONS
// ============================================================

final quickActionContributionsProvider = FutureProvider<List<QuickActionContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.quickActions(enabledModules: modules);
});

// ============================================================
// ROUTE CONTRIBUTIONS
// ============================================================

final routeContributionsProvider = FutureProvider<List<RouteContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.routes(enabledModules: modules);
});

// ============================================================
// NOTIFICATION PROVIDER CONTRIBUTIONS
// ============================================================

final notificationContributionProvidersProvider = FutureProvider<List<NotificationProviderContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.notificationProviders(enabledModules: modules);
});

// ============================================================
// SEARCH PROVIDER CONTRIBUTIONS
// ============================================================

final searchContributionProvidersProvider = FutureProvider<List<SearchProviderContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.searchProviders(enabledModules: modules);
});

// ============================================================
// ANALYTICS PROVIDER CONTRIBUTIONS
// ============================================================

final analyticsContributionProvidersProvider = FutureProvider<List<AnalyticsProviderContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.analyticsProviders(enabledModules: modules);
});

// ============================================================
// AI PROVIDER CONTRIBUTIONS
// ============================================================

final aiContributionProvidersProvider = FutureProvider<List<AIProviderContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.aiProviders(enabledModules: modules);
});

// ============================================================
// COMMAND PALETTE CONTRIBUTIONS
// ============================================================

final commandPaletteContributionsProvider = FutureProvider<Map<String, List<CommandPaletteActionContribution>>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.commandPaletteActions(enabledModules: modules);
});

/// All command palette actions as a flat list (for searching).
final commandPaletteFlatListProvider = FutureProvider<List<CommandPaletteActionContribution>>((ref) async {
  final categorized = await ref.watch(commandPaletteContributionsProvider.future);
  final flat = <CommandPaletteActionContribution>[];
  for (final list in categorized.values) {
    flat.addAll(list);
  }
  return flat;
});

// ============================================================
// BACKGROUND JOB CONTRIBUTIONS
// ============================================================

final backgroundJobContributionsProvider = FutureProvider<List<BackgroundJobContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.backgroundJobs(enabledModules: modules);
});

// ============================================================
// SETTINGS PAGE CONTRIBUTIONS
// ============================================================

final settingsPageContributionsProvider = FutureProvider<Map<String, List<SettingsPageContribution>>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.settingsPages(enabledModules: modules);
});

// ============================================================
// REPORT CONTRIBUTIONS
// ============================================================

final reportContributionsProvider = FutureProvider<Map<String, List<ReportContribution>>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.reports(enabledModules: modules);
});

// ============================================================
// FLOATING ACTION BUTTON CONTRIBUTIONS
// ============================================================

final floatingActionButtonContributionsProvider = FutureProvider.family<List<FloatingActionButtonContribution>, String?>((ref, forScreen) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.floatingActionButtons(enabledModules: modules, forScreen: forScreen);
});

// ============================================================
// EXPORT / IMPORT PROVIDER CONTRIBUTIONS
// ============================================================

final exportProviderContributionsProvider = FutureProvider<List<ExportProviderContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.exportProviders(enabledModules: modules);
});

final importProviderContributionsProvider = FutureProvider<List<ImportProviderContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.importProviders(enabledModules: modules);
});

// ============================================================
// ACTIVITY TIMELINE CONTRIBUTIONS
// ============================================================

final activityTimelineContributionsProvider = FutureProvider<Map<String, List<ActivityTimelineItemContribution>>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.activityTimelineItems(enabledModules: modules);
});

// ============================================================
// HELP ARTICLE CONTRIBUTIONS
// ============================================================

final helpArticleContributionsProvider = FutureProvider<List<HelpArticleContribution>>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.helpArticles(enabledModules: modules);
});

// ============================================================
// MODULE-SPECIFIC CONTRIBUTIONS
// ============================================================

final moduleContributionsProvider = FutureProvider.family<ModuleContributions, String>((ref, moduleId) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  final engine = ref.watch(runtimeContributionEngineProvider);
  return engine.allContributionsFor(moduleId: moduleId, enabledModules: modules);
});
