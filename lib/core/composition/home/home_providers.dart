/// ============================================================
/// HOME COMPOSITION PROVIDERS
/// ============================================================
///
/// Riverpod providers for HomeContributionComposer.
/// Provides reactive home composition data to UI components.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/home/home_contribution_composer.dart';
import 'package:famhub_app/core/composition/providers/descriptor_providers.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';

/// ============================================================
/// PROVIDER: HOME COMPOSITION RESULT
/// ============================================================
///
/// Returns the fully composed home screen from module contributions.
/// Rebuilds when modules or context change.
/// ============================================================
final homeCompositionResultProvider = FutureProvider<HomeCompositionResult>((ref) async {
  final modules = await ref.watch(enabledRuntimeModulesProvider.future);
  return HomeContributionComposer.compose(enabledModules: modules);
});

/// ============================================================
/// PROVIDER: HOME ACTIVE SECTIONS
/// ============================================================
///
/// Returns a list of section names that have content on the home screen.
/// ============================================================
final homeActiveSectionsProvider = FutureProvider<List<String>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  return HomeContributionComposer.getActiveSections(result);
});

/// ============================================================
/// PROVIDER: HOME ALERTS
/// ============================================================
final homeAlertsProvider = FutureProvider<List<HomeWidgetContribution>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  return result.alerts;
});

/// ============================================================
/// PROVIDER: HOME RECOMMENDED ACTIONS
/// ============================================================
final homeRecommendedActionsProvider = FutureProvider<List<HomeWidgetContribution>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  return result.recommendedActions;
});

