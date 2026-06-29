/// ============================================================
/// HOME PAGE PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/home/presentation/pages/ = home screen providers
///
/// ✅ Responsibilities:
///   - Additional Riverpod providers for the home screen
///   - Complements the existing homeCompositionResultProvider
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/composition/home/home_providers.dart';
import 'package:famhub_app/core/composition/home/home_contribution_composer.dart';
import 'package:famhub_app/core/composition/contributions/contribution_models.dart';

/// Provider: Home screen section order - determines which sections
/// appear and in what order on the home screen.
final homeSectionOrderProvider = Provider<List<String>>((ref) {
  return [
    'greeting_weather',
    'alerts',
    'recommended_actions',
    'quick_actions',
    'pinned_modules',
    'ai_insights',
    'promotions_news',
    'recent_activity',
  ];
});
