/// ============================================================
/// LOGISTICS TRACKING PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Expose the bounded session list and the bounded location history
///     used by the live/recent tracking experience.
///   - Refresh only on explicit user action (pull-to-refresh / refresh
///     button) — never on a polling timer.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - UI never talks to Supabase.
///   - Backend RLS remains the authorization authority.
///   - Reads only: GPS writes go through the driver tracking controller.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import '../../domain/models/logistics_dashboard_models.dart';
import '../../domain/models/logistics_detail_models.dart';
import 'logistics_dashboard_provider.dart';

EntityContext? _resolvedContext(Ref ref) {
  final context = ref.watch(contextProvider);
  if (context.isLoading || context.isGuest) return null;
  return context;
}

/// Bounded recent-session list for the tracking page.
final logisticsTrackingSessionsProvider =
    FutureProvider<List<LogisticsTrackingSession>>((ref) async {
  final context = _resolvedContext(ref);
  if (context == null) return const [];

  return ref
      .read(logisticsRepositoryProvider)
      .fetchTrackingSessions(entityId: context.entityId);
});

/// Bounded location history for a single tracking session.
///
/// Returns null when the backend does not expose the session.
final logisticsTrackingSessionDetailProvider =
    FutureProvider.family<LogisticsTrackingSessionDetail?, String>((
  ref,
  trackingSessionId,
) async {
  _resolvedContext(ref);
  return ref
      .read(logisticsRepositoryProvider)
      .fetchTrackingSessionDetail(trackingSessionId);
});
