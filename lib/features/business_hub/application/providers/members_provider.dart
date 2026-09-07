/// ============================================================
/// BUSINESS HUB — TEAM & MEMBERS PROVIDERS
/// ============================================================
///
/// Loads the active business's team members from the canonical
/// `core.entity_members` (read-only).
///
/// - `membersByBusinessProvider(entityId)` — family fetch.
/// - `activeBusinessMembersProvider` — reactive read that follows
///   `activeBusinessProvider` and refreshes on business switch.
///
/// RLS scopes member rows to what the current user is authorized to
/// see; no client `user_id` is sent.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/business_hub/domain/entities/business_member.dart';
import 'active_business_provider.dart';
import 'business_hub_repository_provider.dart';

/// Family provider: team members for a specific business entity.
final membersByBusinessProvider =
    FutureProvider.family<List<BusinessMember>, String>((ref, entityId) async {
  final repo = ref.watch(businessHubRepositoryProvider);
  return repo.fetchBusinessMembers(entityId);
});

/// Reactive members for the ACTIVE business (follows the selected
/// business context). Empty list while no business is active.
final activeBusinessMembersProvider = Provider<AsyncValue<List<BusinessMember>>>(
    (ref) {
  final active = ref.watch(activeBusinessProvider);
  if (active == null) return const AsyncValue.data([]);
  return ref.watch(membersByBusinessProvider(active.id));
});
