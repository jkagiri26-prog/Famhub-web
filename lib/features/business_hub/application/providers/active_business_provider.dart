/// ============================================================
/// BUSINESS HUB — ACTIVE BUSINESS PROVIDERS
/// ============================================================
///
/// Establishes the active business/entity context for the Business Hub.
///
///   activeBusinessProvider     → resolved BusinessEntity (from the canonical
///                                active entity context)
///   businessProfileProvider    → optional `commerce.business_profiles`
///                                row for the active business
///
/// The ACTIVE ENTITY is switched centrally from the app-bar Entity switcher
/// (`ContextController.activateContextRow` → `core.entity_context_sessions`).
/// The Business Hub no longer owns any local entity-selection state.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_entity.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_profile.dart';
import 'business_hub_repository_provider.dart';
import 'my_businesses_provider.dart';

/// ============================================================
/// RESOLVED ACTIVE BUSINESS
/// ============================================================

/// The effective active business.
///
/// Resolution order:
///   1. the ACTIVE entity context (`core.entity_context_sessions.entity_id`) —
///      canonical; switched only via the app-bar Entity switcher;
///   2. the first available business.
final activeBusinessProvider = Provider<BusinessEntity?>((ref) {
  final businesses = ref.watch(myBusinessesProvider).value ?? const [];

  if (businesses.isEmpty) return null;

  final contextEntityId =
      ref.watch(contextProvider.select((c) => c.entityId));
  if (contextEntityId != null && contextEntityId.isNotEmpty) {
    for (final business in businesses) {
      if (business.id == contextEntityId) return business;
    }
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
