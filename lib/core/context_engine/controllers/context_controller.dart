import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_storage_service_provider.dart';
import 'package:famhub_app/core/context_engine/services/context_storage_service.dart';
import 'package:famhub_app/core/context_engine/services/context_sync_service.dart';
import 'package:famhub_app/core/session/session_provider.dart';

class ContextController extends Notifier<EntityContext> {
  late final ContextStorageService storage;
  late final ContextSyncService sync;

  @override
  EntityContext build() {
    storage = ref.read(contextStorageServiceProvider);
    sync = ref.read(contextSyncServiceProvider);

    // Re-initialize real context whenever auth state flips.
    ref.listen(isAuthenticatedProvider, (previous, next) {
      if (next == true && previous == false) {
        Future.microtask(init);
      } else if (next == false && previous == true) {
        logout();
      }
    });

    return const EntityContext();
  }

  /// Initialize from the authenticated user's real profile/entity context.
  ///
  /// Local storage is NEVER trusted for identity — fabricated/stale ids
  /// must not be resurrected. Real values are persisted only after a
  /// successful backend fetch. No fallback IDs are invented: when there
  /// is no active profile/entity, the context is explicitly unavailable
  /// (entityId = null, isGuest reflects auth state).
  Future<void> init() async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) {
      state = const EntityContext(isGuest: true, isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true);

    Map<String, dynamic>? remote;
    try {
      remote = await sync.fetchUserContext();
    } catch (_) {
      remote = null;
    }

    if (remote == null) {
      // Authenticated but no profile/context could be resolved — explicit
      // "unavailable", never a fabricated id.
      state = const EntityContext(isGuest: false, isLoading: false);
      return;
    }

    state = EntityContext(
      userId: remote['userId']?.toString(),
      profileId: remote['profileId']?.toString(),
      entityId: remote['entityId']?.toString(),
      roleId: remote['roleId']?.toString(),
      businessProfileId: remote['businessProfileId']?.toString(),
      role: remote['role']?.toString(),
      tier: (remote['tier']?.toString()) ?? 'free',
      isGuest: false,
      isLoading: false,
    );

    await _persist();
  }

  /// Apply the canonical context returned by the backend workspace-selection
  /// completion (`users.complete_workspace_selection`). This updates the
  /// EXISTING context owner — no new provider/identity system is created.
  ///
  /// Only non-null backend values are applied; nothing is fabricated.
  Future<void> applySelectionContext({
    String? profileId,
    String? entityId,
    String? roleId,
    String? role,
    String? businessProfileId,
  }) async {
    state = state.copyWith(
      profileId: profileId,
      entityId: entityId,
      roleId: roleId,
      businessProfileId: businessProfileId,
      role: role,
      isGuest: false,
      isLoading: false,
    );

    await _persist();
  }

  Future<void> switchRole(String role) async {
    state = state.copyWith(role: role, isLoading: false);
    await _persist();
  }

  Future<void> switchEntity(String entityId) async {
    state = state.copyWith(entityId: entityId, isLoading: false);
    await _persist();
  }

  Future<void> logout() async {
    await storage.clear();
    state = const EntityContext(isGuest: true, isLoading: false);
  }

  Future<void> _persist() async {
    await storage.save(
      userId: state.userId,
      profileId: state.profileId,
      role: state.role,
      roleId: state.roleId,
      entityId: state.entityId,
      businessProfileId: state.businessProfileId,
      tier: state.tier,
    );
  }
}
