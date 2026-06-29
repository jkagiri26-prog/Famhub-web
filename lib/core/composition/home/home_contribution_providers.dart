/// ============================================================
/// HOME CONTRIBUTION PROVIDERS (EXTENDED)
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/composition/home/ = extended home contribution providers
///
/// ✅ Responsibilities:
///   - Provides more granular home data for sections
///   - Alerts, quick actions, AI insights, activity timeline
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/home/home_providers.dart';
import 'package:famhub_app/core/composition/home/home_contribution_composer.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';
import 'package:famhub_app/core/composition/contributions/contribution_registry.dart';

/// Provider: All alerts from enabled modules
final homeAlertsProvider = FutureProvider<List<HomeWidgetContribution>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  return result.alerts;
});

/// Provider: Home weather info
final homeWeatherProvider = FutureProvider<List<HomeWidgetContribution>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  return result.weather;
});

/// Provider: Home promotions
final homePromotionsProvider = FutureProvider<List<HomeWidgetContribution>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  return result.promotions;
});

/// Provider: Home news items
final homeNewsProvider = FutureProvider<List<HomeWidgetContribution>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  return result.news;
});

/// Provider: AI suggestions for home
final homeAiSuggestionsProvider = FutureProvider<List<HomeWidgetContribution>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  return result.aiSuggestions;
});

/// Provider: Recent activity items
final homeRecentActivityProvider = FutureProvider<List<HomeWidgetContribution>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  return result.recentActivity;
});

/// Provider: Entity reminders
final homeEntityRemindersProvider = FutureProvider<List<HomeWidgetContribution>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  // Entity reminders are a sub-type of alerts
  return result.alerts.where((a) => a.widgetType == 'reminder').toList();
});

/// Provider: Market prices home widget
final homeMarketPricesProvider = FutureProvider<List<HomeWidgetContribution>>((ref) async {
  final result = await ref.watch(homeCompositionResultProvider.future);
  return result.promotions.where((p) => p.widgetType == 'price').toList();
});
