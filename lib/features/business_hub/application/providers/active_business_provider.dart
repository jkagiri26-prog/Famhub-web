/// ============================================================
/// BUSINESS HUB — ACTIVE BUSINESS PROVIDERS
/// ============================================================
///
/// Establishes the active business/entity context for the Business Hub.
///
///   activeBusinessIdProvider   → explicit user selection (nullable)
///   activeBusinessProvider     → resolved BusinessEntity (defaults to the
///                                first available business)
///   businessProfileProvider    → optional `commerce.business_profiles`
///                                row for the active business
///
/// A user may operate multiple entities and an entity may hold multiple
/// business activities. Selection is by entity id only — no separate
/// "business type" mode is introduced.
///
/// Canonical context note: when the backend `core.entity_context_sessions`
/// flow is wired on the frontend, this selection should reconcile with it
/// instead of becoming a parallel context singleton.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/features/business_hub/domain/entities/business_entity.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_profile.dart';
import 'business_hub_repository_provider.dart';
import 'my_businesses_provider.dart';

/// ============================================================
/// ACTIVE BUSINESS SELECTION (EXPLICIT USER CHOICE)
/// ============================================================

class ActiveBusinessController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Select a business entity id (null clears to the default business).
  void select(String? entityId) {
    state = entityId;
  }
}

/// The user's explicitly selected business id (nullable).
final activeBusinessIdProvider =
    NotifierProvider<ActiveBusinessController, String?>(
  ActiveBusinessController.new,
);

/// ============================================================
/// RESOLVED ACTIVE BUSINESS
/// ============================================================

/// The effective active business. Falls back to the first available
/// business when nothing is explicitly selected.
final activeBusinessProvider = Provider<BusinessEntity?>((ref) {
  final businesses = ref.watch(myBusinessesProvider).value ?? const [];

  if (businesses.isEmpty) return null;

  final selectedId = ref.watch(activeBusinessIdProvider);
  if (selectedId == null) return businesses.first;

  for (final business in businesses) {
    if (business.id == selectedId) return business;
  }
  return businesses.first;
});

/// ============================================================
/// OPTIONAL BUSINESS PROFILE
/// ============================================================

/// The optional `commerce.business_profiles` row for an entity.
final businessProfileProvider =
    FutureProvider.family<BusinessProfile?, String>((ref, entityId) async {
  final repo = ref.watch(businessHubRepositoryProvider);
  return repo.fetchBusinessProfile(entityId);
});
