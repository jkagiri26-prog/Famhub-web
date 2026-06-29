/// ============================================================
/// HOME CONTRIBUTION COMPOSER (ENTERPRISE PHASE)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/home/ = home composition layer
///
/// ✅ Responsibilities:
///   - Compose the home screen from module contributions
///   - Aggregate: greeting, alerts, news, promotions, weather,
///     recommended actions, pinned modules, quick actions,
///     recent activity, AI suggestions
///   - Everything contributed by enabled modules
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - NO hardcoded home screen elements
///   - Everything flows through the Contribution Engine
///   - Governance already applied by the time data arrives
/// ============================================================
library;

import 'package:famhub_app/core/composition/domain/models/runtime_module.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';
import 'package:famhub_app/core/composition/contributions/runtime_contribution_engine.dart';

/// ============================================================
/// HOME COMPOSITION RESULT
/// ============================================================
///
/// The fully composed home screen model, ready for rendering.
/// Every element is contributed by an enabled module.
/// ============================================================
class HomeCompositionResult {
  final List<HomeWidgetContribution> greetings;
  final List<HomeWidgetContribution> alerts;
  final List<HomeWidgetContribution> news;
  final List<HomeWidgetContribution> promotions;
  final List<HomeWidgetContribution> weather;
  final List<HomeWidgetContribution> recommendedActions;
  final List<HomeWidgetContribution> pinnedModules;
  final List<QuickActionContribution> quickActions;
  final List<HomeWidgetContribution> recentActivity;
  final List<HomeWidgetContribution> aiSuggestions;

  const HomeCompositionResult({
    this.greetings = const [],
    this.alerts = const [],
    this.news = const [],
    this.promotions = const [],
    this.weather = const [],
    this.recommendedActions = const [],
    this.pinnedModules = const [],
    this.quickActions = const [],
    this.recentActivity = const [],
    this.aiSuggestions = const [],
  });

  bool get isEmpty =>
      greetings.isEmpty &&
      alerts.isEmpty &&
      news.isEmpty &&
      promotions.isEmpty &&
      weather.isEmpty &&
      recommendedActions.isEmpty &&
      pinnedModules.isEmpty &&
      quickActions.isEmpty &&
      recentActivity.isEmpty &&
      aiSuggestions.isEmpty;

  bool get hasAlerts => alerts.isNotEmpty;
  bool get hasNews => news.isNotEmpty;
  bool get hasPromotions => promotions.isNotEmpty;
  bool get hasWeather => weather.isNotEmpty;
  bool get hasRecommendations => recommendedActions.isNotEmpty;
  bool get hasPinnedModules => pinnedModules.isNotEmpty;
  bool get hasQuickActions => quickActions.isNotEmpty;
  bool get hasRecentActivity => recentActivity.isNotEmpty;
  bool get hasAiSuggestions => aiSuggestions.isNotEmpty;
}

/// ============================================================
/// HOME CONTRIBUTION COMPOSER
/// ============================================================
///
/// Composes the home screen from module contributions.
/// Call compose() with enabled modules to get the full result.
///
/// Usage:
///   final result = HomeContributionComposer.compose(enabledModules);
///   // result.greetings, result.alerts, result.recommendedActions, etc.
/// ============================================================
class HomeContributionComposer {
  /// ============================================================
  /// COMPOSE HOME SCREEN
  /// ============================================================
  ///
  /// Takes a list of enabled RuntimeModules (after governance filtering)
  /// and produces a fully composed HomeCompositionResult.
  ///
  /// Every element comes from module contributions — nothing is hardcoded.
  /// ============================================================
  static HomeCompositionResult compose({
    required List<RuntimeModule> enabledModules,
  }) {
    final homeComposition = runtimeContributionEngine.homeComposition(
      enabledModules: enabledModules,
    );

    final quickActions = runtimeContributionEngine.quickActions(
      enabledModules: enabledModules,
    );

    return HomeCompositionResult(
      greetings: homeComposition.greetings,
      alerts: homeComposition.alerts,
      news: homeComposition.news,
      promotions: homeComposition.promotions,
      weather: homeComposition.weather,
      recommendedActions: homeComposition.recommendedActions,
      pinnedModules: homeComposition.pinnedModules,
      quickActions: quickActions,
      recentActivity: homeComposition.recentActivity,
      aiSuggestions: homeComposition.aiSuggestions,
    );
  }

  /// ============================================================
  /// COMPOSE WITH FILTER (FOR SPECIFIC HOME SECTIONS)
  /// ============================================================
  ///
  /// Returns only the requested section types.
  /// ============================================================
  static HomeCompositionResult composeWithFilter({
    required List<RuntimeModule> enabledModules,
    required List<String> includeTypes,
  }) {
    final full = compose(enabledModules: enabledModules);

    return HomeCompositionResult(
      greetings: includeTypes.contains('greeting') ? full.greetings : [],
      alerts: includeTypes.contains('alert') ? full.alerts : [],
      news: includeTypes.contains('news') ? full.news : [],
      promotions: includeTypes.contains('promotion') ? full.promotions : [],
      weather: includeTypes.contains('weather') ? full.weather : [],
      recommendedActions: includeTypes.contains('recommended_action') ? full.recommendedActions : [],
      pinnedModules: includeTypes.contains('pinned_module') ? full.pinnedModules : [],
      quickActions: includeTypes.contains('quick_action') ? full.quickActions : [],
      recentActivity: includeTypes.contains('recent_activity') ? full.recentActivity : [],
      aiSuggestions: includeTypes.contains('ai_suggestion') ? full.aiSuggestions : [],
    );
  }

  /// ============================================================
  /// GET ACTIVE SECTIONS
  /// ============================================================
  ///
  /// Returns a list of section names that have content.
  /// Useful for building dynamic section lists on the home screen.
  /// ============================================================
  static List<String> getActiveSections(HomeCompositionResult result) {
    final sections = <String>[];

    if (result.hasAlerts) sections.add('alerts');
    if (result.hasNews) sections.add('news');
    if (result.hasPromotions) sections.add('promotions');
    if (result.hasWeather) sections.add('weather');
    if (result.hasRecommendations) sections.add('recommended_actions');
    if (result.hasPinnedModules) sections.add('pinned_modules');
    if (result.hasQuickActions) sections.add('quick_actions');
    if (result.hasRecentActivity) sections.add('recent_activity');
    if (result.hasAiSuggestions) sections.add('ai_suggestions');

    return sections;
  }
}
