/// ============================================================
/// BUSINESS HUB — LISTINGS PROVIDERS
/// ============================================================
///
/// Loads the active business's marketplace listings (read/management
/// visibility) via the composed Marketplace repository path, scoped to
/// the active business entity (`marketplace.listings.entity_id`).
///
/// - `listingsByBusinessProvider(entityId)` — family fetch.
/// - `activeBusinessListingsProvider` — reactive read that follows
///   `activeBusinessProvider` and refreshes on business switch.
///
/// Ownership stays server-side under RLS; no client `user_id` is sent.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/business_hub/domain/entities/business_listing.dart';
import 'active_business_provider.dart';
import 'business_hub_repository_provider.dart';

/// Family provider: listings for a specific business entity.
final listingsByBusinessProvider =
    FutureProvider.family<List<BusinessListing>, String>((ref, entityId) async {
  final repo = ref.watch(businessHubRepositoryProvider);
  return repo.fetchListings(entityId);
});

/// Reactive listings for the ACTIVE business (follows the selected
/// business context). Empty list while no business is active.
final activeBusinessListingsProvider =
    Provider<AsyncValue<List<BusinessListing>>>((ref) {
  final active = ref.watch(activeBusinessProvider);
  if (active == null) return const AsyncValue.data([]);
  return ref.watch(listingsByBusinessProvider(active.id));
});
