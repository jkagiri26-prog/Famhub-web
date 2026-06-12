import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/dashboard_engine/application/composition/dashboard_composition_engine.dart';
/// ============================================================
/// DASHBOARD PROVIDERS (APPLICATION LAYER ONLY)
/// ============================================================
///
/// Rules:
/// - NO UI logic
/// - NO widget construction
/// - ONLY dependency wiring
/// ============================================================

/// ------------------------------------------------------------
/// MODULE LOADER
/// ------------------------------------------------------------
final dashboardProvider =
    FutureProvider.family<List<dynamic>, String>((ref, moduleKey) async {
  /// TODO: Replace with repository call
  /// Example:
  /// return ref.read(dashboardRepositoryProvider).loadModules(moduleKey);

  return const <dynamic>[];
});

/// ------------------------------------------------------------
/// COMPOSITION ENGINE PROVIDER (SYNC SINGLETON)
/// ------------------------------------------------------------
final dashboardCompositionEngineProvider = Provider<DashboardCompositionEngine>(
  (ref) {
    return DashboardCompositionEngine();
  },
);
