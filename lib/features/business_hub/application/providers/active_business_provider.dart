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

import 'package:famhub_app/core/context_engine/providers/context_provider.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_entity.dart';
import 'package:famhub_app/features/business_hub/domain/entities/business_profile.dart';
import 'business_hub_repository_provider.dart';
import 'my_businesses_provider.dart';

/// ============================================================
/// AUTHORIZED CONTEXTS FOR THE ACTIVE WORKSPACE (READ-ONLY)
/// ============================================================
///
/// The entity choices the user may switch between are exactly the contexts
/// returned by the canonical `users.get_available_workspace_contexts()` for
/// the CURRENT workspace — never an arbitrary `core.entities` row. This keeps
/// the existing workspace/entity/role authorization model.
final currentWorkspaceContextsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final workspaceId =
      ref.watch(activeWorkspaceProvider.select((w) => w.workspaceId));
  if (workspaceId.isEmpty) return const [];

  final authService = ref.read(authServiceProvider);
  final all = await authService.getAvailableWorkspaceContexts();
  return all
      .where((c) => c['workspace_id']?.toString() == workspaceId)
      .toList();
});

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

/// The effective active business.
///
/// Resolution order:
///   1. the ACTIVE entity context (`core.entity_context_sessions.entity_id`) —
///      canonical; entity switching now activates it, so it can never be
///      contradicted by local UI state;
///   2. explicit in-Hub selection (`activeBusinessIdProvider`) — only a
///      fallback when the context entity is not among the known businesses;
///   3. the first available business.
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

  final selectedId = ref.watch(activeBusinessIdProvider);
  if (selectedId != null) {
    for (final business in businesses) {
      if (business.id == selectedId) return business;
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
