import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../composition/dashboard_composition_engine.dart';
import '../../infrastructure/services/dashboard_renderer_service.dart';

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

/// ------------------------------------------------------------
/// RENDERER PROVIDER (SYNC - NOT FUTURE)
/// ------------------------------------------------------------
/// ⚠️ IMPORTANT CHANGE:
/// Renderer should NOT be async.
/// Rendering must be deterministic and instant.
final dashboardRendererProvider =
    Provider.family<DashboardRendererService, String>(
  (ref, moduleKey) {
    return const DashboardRendererService();
  },
);