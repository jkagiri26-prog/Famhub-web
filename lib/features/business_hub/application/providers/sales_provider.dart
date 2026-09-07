/// ============================================================
/// BUSINESS HUB — SALES PROVIDERS
/// ============================================================
///
/// Loads the active business's sales orders from the canonical
/// `commerce.orders` (scoped via the business's seller profiles).
///
/// - `salesOrdersByBusinessProvider(entityId)` — raw family fetch keyed
///   on the business entity id.
/// - `activeBusinessSalesOrdersProvider` — reactive read that follows
///   the active business selection.
/// - `orderItemsByOrderProvider(orderId)` — item lines for one order.
///
/// Ownership stays server-side under RLS; the client never sends a
/// `user_id`.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/business_hub/domain/entities/sales_order.dart';
import 'package:famhub_app/features/business_hub/domain/entities/sales_order_line.dart';
import 'active_business_provider.dart';
import 'business_hub_repository_provider.dart';

/// Family provider: sales orders for a specific business entity.
final salesOrdersByBusinessProvider =
    FutureProvider.family<List<SalesOrder>, String>((ref, entityId) async {
  final repo = ref.watch(businessHubRepositoryProvider);
  return repo.fetchSalesOrders(entityId);
});

/// Reactive sales orders for the ACTIVE business (follows the selected
/// business context). Empty list while no business is active.
final activeBusinessSalesOrdersProvider =
    Provider<AsyncValue<List<SalesOrder>>>((ref) {
  final active = ref.watch(activeBusinessProvider);
  if (active == null) return const AsyncValue.data([]);
  return ref.watch(salesOrdersByBusinessProvider(active.id));
});

/// Item lines for a single order (lazily loaded in the detail sheet).
final orderItemsByOrderProvider =
    FutureProvider.family<List<SalesOrderLine>, String>((ref, orderId) async {
  final repo = ref.watch(businessHubRepositoryProvider);
  return repo.fetchOrderItems(orderId);
});
