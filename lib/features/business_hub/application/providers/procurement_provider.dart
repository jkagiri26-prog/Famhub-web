/// ============================================================
/// BUSINESS HUB — PROCUREMENT PROVIDERS
/// ============================================================
///
/// Loads the active business's purchase orders from the canonical
/// `commerce.purchase_orders` (entity-scoped via the business's owner +
/// members).
///
/// - `purchaseOrdersByBusinessProvider(entityId)` — raw family fetch
///   keyed on the business entity id.
/// - `activeBusinessPurchaseOrdersProvider` — reactive read that follows
///   the active business selection.
///
/// Ownership stays server-side under RLS; the client never sends a
/// `user_id`.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/business_hub/domain/entities/purchase_order.dart';
import 'active_business_provider.dart';
import 'business_hub_repository_provider.dart';

/// Family provider: purchase orders for a specific business entity.
final purchaseOrdersByBusinessProvider =
    FutureProvider.family<List<PurchaseOrder>, String>((ref, entityId) async {
  final repo = ref.watch(businessHubRepositoryProvider);
  return repo.fetchPurchaseOrders(entityId);
});

/// Reactive purchase orders for the ACTIVE business (follows the
/// selected business context). Empty list while no business is active.
final activeBusinessPurchaseOrdersProvider =
    Provider<AsyncValue<List<PurchaseOrder>>>((ref) {
  final active = ref.watch(activeBusinessProvider);
  if (active == null) return const AsyncValue.data([]);
  return ref.watch(purchaseOrdersByBusinessProvider(active.id));
});
