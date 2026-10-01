/// ============================================================
/// LOGISTICS SHIPMENT PROVIDERS
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   features/logistics/application/providers/ = application layer
///
/// ✅ Responsibilities:
///   - Expose the bounded shipment list, the shipment detail payload
///     and the best-effort transport administration options.
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

import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import '../../domain/models/logistics_dashboard_models.dart';
import '../../domain/models/logistics_detail_models.dart';
import '../../domain/repositories/logistics_repository.dart';
import 'logistics_dashboard_provider.dart';

/// Null while the context is still resolving or the user is a guest —
/// callers render their loading / permission state instead of reading.
EntityContext? _resolvedContext(Ref ref) {
  final context = ref.watch(contextProvider);
  if (context.isLoading || context.isGuest) return null;
  return context;
}

/// Bounded shipment list for the shipments page.
final logisticsShipmentsProvider =
    FutureProvider<List<LogisticsShipment>>((ref) async {
  final context = _resolvedContext(ref);
  if (context == null) return const [];

  return ref
      .read(logisticsRepositoryProvider)
      .fetchShipments(entityId: context.entityId);
});

/// Bounded, fully assembled shipment detail.
///
/// Returns null when the backend does not expose the shipment — the page
/// then renders its own "not available" state.
final logisticsShipmentDetailProvider =
    FutureProvider.family<LogisticsShipmentDetail?, String>((
  ref,
  shipmentId,
) async {
  final context = _resolvedContext(ref);
  if (context == null) return null;

  return ref
      .read(logisticsRepositoryProvider)
      .fetchShipmentDetail(shipmentId, entityId: context.entityId);
});

/// Best-effort candidate lists for the assign-transport dialog.
final logisticsTransportOptionsProvider =
    FutureProvider<LogisticsTransportOptions>((ref) async {
  final context = _resolvedContext(ref);
  if (context == null) return LogisticsTransportOptions.empty;

  return ref
      .read(logisticsRepositoryProvider)
      .fetchTransportOptions(entityId: context.entityId);
});
