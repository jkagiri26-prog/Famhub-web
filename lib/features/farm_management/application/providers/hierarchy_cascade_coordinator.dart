/// ============================================================
/// HIERARCHY CASCADE COORDINATOR
/// ============================================================
///
/// 🏗️ ARCHITECTURE RULE:
///   When hierarchy selection changes, dependent providers must
///   automatically invalidate to re-fetch data for the new context.
///
///   Selecting a Farm → invalidates fields, crops, livestock, activities
///   Selecting a Field → invalidates crops, livestock, activities
///   Selecting a Crop/Livestock → invalidates activities
///
/// ⚠️ Uses post-frame scheduling to avoid circular dependency issues.
/// Only depends on hierarchy_provider.dart for the version watch;
/// other provider imports are for invalidation targets.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/features/farm_management/application/providers/hierarchy_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/fields_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/crops_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/livestock_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/activities_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/assets_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/production_provider.dart';

import 'package:famhub_app/features/farm_management/application/providers/farm_dashboard_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_lifecycle_provider.dart';
import 'package:famhub_app/features/farm_management/application/providers/farm_ai_context_provider.dart';

/// Watches hierarchy version changes and invalidates dependent providers.
class HierarchyCascadeCoordinator {
  final Ref ref;

  HierarchyCascadeCoordinator(this.ref);

  /// Set up listener — call once when the module initializes (via bootstrap).
  ///
  /// Uses `ref.listen` to watch hierarchy version without creating
  /// a new provider. Invalidations are scheduled post-frame to prevent
  /// "reading provider during build" errors.
  void setupListener() {
    ref.listen<int>(_hierarchyVersionProvider, (previous, next) {
      if (previous == null || next == previous) return;

      final hierarchy = ref.read(hierarchyProvider);

      // Post-frame to avoid circular read during build
      Future.microtask(() {
        try {
          // Always invalidate dashboard, lifecycle, and AI context
          ref.invalidate(farmDashboardProvider);
          ref.invalidate(farmLifecycleProvider);
          ref.invalidate(farmAiContextProvider);

          if (!hierarchy.hasEntity) {
            // No farm selected → clear everything
            ref.invalidate(fieldsProvider);
            ref.invalidate(cropsProvider);
            ref.invalidate(livestockProvider);
            ref.invalidate(activitiesProvider);
            ref.invalidate(assetsProvider);
            ref.invalidate(productionProvider);
          } else if (!hierarchy.hasField) {
            // Farm changed → reload fields, clear deeper
            ref.invalidate(fieldsProvider);
            ref.invalidate(cropsProvider);
            ref.invalidate(livestockProvider);
            ref.invalidate(activitiesProvider);
            ref.invalidate(assetsProvider);
            ref.invalidate(productionProvider);
          } else if (!hierarchy.hasCropOrLivestock) {
            // Field changed → reload crops/livestock, clear activities
            ref.invalidate(cropsProvider);
            ref.invalidate(livestockProvider);
            ref.invalidate(activitiesProvider);
            ref.invalidate(productionProvider);
          } else {
            // Crop/Livestock changed → reload activities
            ref.invalidate(activitiesProvider);
            ref.invalidate(productionProvider);
          }
        } catch (_) {
          // Non-critical — providers re-resolve on next watch
        }
      });
    });
  }

  /// Centralized mutation-success refresh.
  ///
  /// Call this after ANY successful repository/workflow mutation
  /// (create farm/field/crop/livestock, activity, production) so the
  /// dashboard, lifecycle stage/health/recommendations, and AI context
  /// always reflect fresh data — regardless of which page initiated the
  /// mutation. Individual pages must NOT duplicate these invalidations.
  void refreshAfterMutation() {
    ref.invalidate(farmDashboardProvider);
    ref.invalidate(farmLifecycleProvider);
    ref.invalidate(farmAiContextProvider);
  }

  /// Internal provider that just emits the hierarchy version number.
  /// This is safe because it only watches hierarchy, which doesn't
  /// import any of the invalidation target providers.
  static final _hierarchyVersionProvider = Provider<int>((ref) {
    return ref.watch(hierarchyProvider.select((s) => s.version));
  });
}

/// Singleton provider for the cascade coordinator.
/// Call ref.read(hierarchyCascadeCoordinatorProvider).setupListener() once.
final hierarchyCascadeCoordinatorProvider =
    Provider<HierarchyCascadeCoordinator>((ref) {
  return HierarchyCascadeCoordinator(ref);
});