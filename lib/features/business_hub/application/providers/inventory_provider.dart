/// ============================================================
/// BUSINESS HUB — INVENTORY PROVIDERS
/// ============================================================
///
/// Loads the active business's inventory from the canonical
/// `commerce.stock_registry` (scoped to the active business entity).
///
/// - `inventoryByBusinessProvider(entityId)` — raw family fetch keyed on
///   the business entity id.
/// - `activeBusinessInventoryProvider` — reactive read that follows the
///   active business selection (re-fetches on business switch).
///
/// Ownership stays server-side under RLS; `entityId` only scopes to the
/// active business the caller already can see.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/business_hub/domain/entities/inventory_item.dart';
import 'active_business_provider.dart';
import 'business_hub_repository_provider.dart';

/// Family provider: inventory rows for a specific business entity.
final inventoryByBusinessProvider =
    FutureProvider.family<List<InventoryItem>, String>((ref, entityId) async {
  final repo = ref.watch(businessHubRepositoryProvider);
  return repo.fetchInventory(entityId);
});

/// Reactive inventory for the ACTIVE business (follows the selected
/// business context). Empty list while no business is active.
final activeBusinessInventoryProvider =
    Provider<AsyncValue<List<InventoryItem>>>((ref) {
  final active = ref.watch(activeBusinessProvider);
  if (active == null) return const AsyncValue.data([]);
  return ref.watch(inventoryByBusinessProvider(active.id));
});
