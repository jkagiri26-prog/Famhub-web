/// ============================================================
/// LOGISTICS DASHBOARD PROVIDER
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Expose the bounded Logistics dashboard snapshot through Riverpod.
///   - Re-read when the active entity changes, using the entity id
///     already derived by the FAMHUB context mechanism.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - UI never talks to Supabase.
///   - No ownership id is invented here — only the active entity id.
///   - Backend RLS remains the authorization authority.
///
/// ❌ Does NOT:
///   - Poll, subscribe, or cache outside Riverpod
///   - Grant permissions
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import '../../domain/models/logistics_dashboard_models.dart';
import '../../domain/repositories/logistics_repository.dart';
import '../../infrastructure/repositories/logistics_repository_impl.dart';

/// Repository layer — UI never reaches Supabase directly.
final logisticsRepositoryProvider = Provider<LogisticsRepository>((ref) {
  return LogisticsRepositoryImpl();
});

/// Bounded Logistics dashboard data.
final logisticsDashboardProvider = AsyncNotifierProvider<
    LogisticsDashboardController,
    LogisticsDashboardSnapshot>(LogisticsDashboardController.new);

class LogisticsDashboardController
    extends AsyncNotifier<LogisticsDashboardSnapshot> {
  @override
  Future<LogisticsDashboardSnapshot> build() async {
    // Re-read whenever the active entity, guest flag, or loading
    // state of the existing context mechanism changes.
    final entityId = ref.watch(
      contextProvider.select((c) => c.entityId),
    );
    final isLoading = ref.watch(
      contextProvider.select((c) => c.isLoading),
    );
    final isGuest = ref.watch(
      contextProvider.select((c) => c.isGuest),
    );

    // No authenticated context → no reads. The page renders its own
    // loading / permission state instead of hitting the network.
    if (isLoading || isGuest) return LogisticsDashboardSnapshot.empty;

    return ref
        .read(logisticsRepositoryProvider)
        .fetchDashboard(entityId: entityId);
  }
}
