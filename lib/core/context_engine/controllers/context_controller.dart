import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:famhub_app/core/context_engine/domain/models/entity_context.dart';
import 'package:famhub_app/core/context_engine/providers/context_storage_service_provider.dart';
import 'package:famhub_app/core/context_engine/services/context_storage_service.dart';
import 'package:famhub_app/core/context_engine/services/context_sync_service.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/session/session_provider.dart';
import 'package:famhub_app/core/workspace/application/active_workspace_provider.dart';

class ContextController extends Notifier<EntityContext> {
  late final ContextStorageService storage;
  late final ContextSyncService sync;
  int _refreshGeneration = 0;

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

    ref.listen(sessionProvider, (previous, next) {
      if (previous is! AuthenticatedSession ||
          next is! AuthenticatedSession ||
          previous.userId == null ||
          previous.userId != next.userId) {
        return;
      }
      final previousProfileId = previous.profile?['id']?.toString();
      final nextProfileId = next.profile?['id']?.toString();
      if (previousProfileId == nextProfileId) return;

      // Invalidate pending work immediately, before the authoritative refresh
      // begins, so an older request cannot replace this profile's context.
      ++_refreshGeneration;
      state = const EntityContext(isGuest: false, isLoading: true);
      Future.microtask(init);
    });

    // Reload the active context (and therefore every permission/capability
    // derived from it) on sign-in and token refresh. Never query permissions
    // while the session is null/loading.
    final authSub = SupabaseService.instance.authStateChanges.listen((event) {
      switch (event.event) {
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          if (event.session != null) Future.microtask(init);
          break;
        case AuthChangeEvent.signedOut:
          Future.microtask(logout);
          break;
        default:
          break;
      }
    });
    ref.onDispose(authSub.cancel);

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
    final generation = ++_refreshGeneration;
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    final initiatingUserId = SupabaseService.instance.currentUserId;
    final initiatingSession = ref.read(sessionProvider);
    final initiatingProfileId = initiatingSession is AuthenticatedSession
        ? initiatingSession.profile?['id']?.toString()
        : null;

    bool isCurrentUserRequest() {
      if (generation != _refreshGeneration ||
          !isAuthenticated ||
          !ref.read(isAuthenticatedProvider) ||
          initiatingUserId == null ||
          initiatingProfileId == null ||
          initiatingProfileId.isEmpty ||
          SupabaseService.instance.currentUserId != initiatingUserId) {
        return false;
      }
      final session = ref.read(sessionProvider);
      if (session is! AuthenticatedSession ||
          session.userId != initiatingUserId ||
          session.profile?['id']?.toString() != initiatingProfileId) {
        return false;
      }
      return true;
    }

    bool isCurrentRefresh({String? profileId}) {
      if (generation != _refreshGeneration ||
          ref.read(isAuthenticatedProvider) != isAuthenticated) {
        return false;
      }
      if (!isAuthenticated) {
        return SupabaseService.instance.currentUserId == null &&
            ref.read(sessionProvider) is! AuthenticatedSession;
      }
      if (initiatingUserId == null ||
          SupabaseService.instance.currentUserId != initiatingUserId) {
        return false;
      }
      final session = ref.read(sessionProvider);
      if (session is! AuthenticatedSession ||
          session.userId != initiatingUserId) {
        return false;
      }
      final currentProfileId = session.profile?['id']?.toString();
      final expectedProfileId = profileId ?? initiatingProfileId;
      if (profileId != null &&
          initiatingProfileId != null &&
          profileId != initiatingProfileId) {
        return false;
      }
      return expectedProfileId == null ||
          currentProfileId == expectedProfileId;
    }

    if (isAuthenticated &&
        (initiatingUserId == null ||
            initiatingUserId.isEmpty ||
            initiatingProfileId == null ||
            initiatingProfileId.isEmpty)) {
      state = const EntityContext(isGuest: false, isLoading: false);
      return;
    }

    if (!isAuthenticated) {
      state = const EntityContext(isGuest: true, isLoading: false);
      await ref
          .read(activeWorkspaceProvider.notifier)
          .reconcileWithActiveContext(isCurrent: isCurrentRefresh);
      return;
    }

    state = const EntityContext(isGuest: false, isLoading: true);

    Map<String, dynamic>? remote;
    try {
      remote = await sync.fetchUserContext();
    } catch (_) {
      remote = null;
    }
    if (!isCurrentRefresh()) {
      return;
    }

    if (remote == null) {
      await ref
          .read(activeWorkspaceProvider.notifier)
          .reconcileWithActiveContext(isCurrent: isCurrentRefresh);
      if (isCurrentRefresh()) {
        state = const EntityContext(isGuest: false, isLoading: false);
      }
      return;
    }

    final userId = remote['userId']?.toString();
    final profileId = remote['profileId']?.toString();
    final activeWorkspaceId = remote['workspaceId']?.toString();
    final entityId = remote['entityId']?.toString();
    final roleId = remote['roleId']?.toString();
    final role = remote['role']?.toString();
    final authenticatedUserId = SupabaseService.instance.currentUserId;
    if (userId == null ||
        userId.isEmpty ||
        userId != authenticatedUserId ||
        profileId == null ||
        profileId.isEmpty ||
        activeWorkspaceId == null ||
        activeWorkspaceId.isEmpty ||
        entityId == null ||
        entityId.isEmpty ||
        roleId == null ||
        roleId.isEmpty ||
        role == null ||
        role.isEmpty) {
      await ref
          .read(activeWorkspaceProvider.notifier)
          .reconcileWithActiveContext(isCurrent: isCurrentUserRequest);
      if (isCurrentUserRequest()) {
        state = const EntityContext(isGuest: false, isLoading: false);
      }
      return;
    }
    if (initiatingUserId != userId ||
        !isCurrentRefresh(profileId: profileId)) {
      if (isCurrentUserRequest()) {
        await ref
            .read(activeWorkspaceProvider.notifier)
            .reconcileWithActiveContext(isCurrent: isCurrentUserRequest);
        if (isCurrentUserRequest()) {
          state = const EntityContext(isGuest: false, isLoading: false);
        }
      }
      return;
    }

    // Startup reconciliation (READ-ONLY): align the displayed workspace with
    // the authoritative active entity context before publishing the context.
    // This never activates a context or mutates entity_context_sessions.
    bool reconciled;
    try {
      reconciled = await ref
          .read(activeWorkspaceProvider.notifier)
          .reconcileWithActiveContext(
            workspaceId: activeWorkspaceId,
            entityId: entityId,
            roleId: roleId,
            activeMode: role,
            businessProfileId: remote['businessProfileId']?.toString(),
            authenticatedUserId: userId,
            profileId: profileId,
            isCurrent: () => isCurrentRefresh(profileId: profileId),
          );
    } catch (e) {
      debugPrint('[ContextStartup] workspace reconciliation skipped: $e');
      reconciled = false;
    }
    if (!isCurrentRefresh(profileId: profileId)) return;
    if (!reconciled) {
      state = const EntityContext(isGuest: false, isLoading: false);
      return;
    }

    state = EntityContext(
      userId: userId,
      profileId: profileId,
      activeWorkspaceId: activeWorkspaceId,
      entityId: entityId,
      roleId: roleId,
      businessProfileId: remote['businessProfileId']?.toString(),
      role: role,
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
  int beginSelectionOperation({
    required String userId,
    required String profileId,
  }) {
    if (!_matchesAuthenticatedIdentity(userId, profileId)) return -1;
    return ++_refreshGeneration;
  }

  bool selectionOperationIsCurrent({
    required int generation,
    required String userId,
    required String profileId,
  }) =>
      generation >= 0 &&
      generation == _refreshGeneration &&
      _matchesAuthenticatedIdentity(userId, profileId);

  bool markSelectionPending({
    required int generation,
    required String userId,
    required String profileId,
  }) {
    if (!selectionOperationIsCurrent(
      generation: generation,
      userId: userId,
      profileId: profileId,
    )) {
      return false;
    }
    state = const EntityContext(isGuest: false, isLoading: true);
    return true;
  }

  Future<bool> applySelectionContext({
    required String userId,
    required String profileId,
    required String activeWorkspaceId,
    required String entityId,
    required String roleId,
    required String role,
    String? businessProfileId,
    int? expectedGeneration,
  }) async {
    if (!_matchesAuthenticatedIdentity(userId, profileId) ||
        (expectedGeneration != null &&
            !selectionOperationIsCurrent(
              generation: expectedGeneration,
              userId: userId,
              profileId: profileId,
            ))) {
      return false;
    }
    _refreshGeneration++;
    state = EntityContext(
      userId: userId,
      profileId: profileId,
      activeWorkspaceId: activeWorkspaceId,
      entityId: entityId,
      roleId: roleId,
      businessProfileId: businessProfileId,
      role: role,
      isGuest: false,
      isLoading: false,
    );

    await _persist();
    return true;
  }

  /// Canonical entity/workspace context activation (existing architecture).
  ///
  /// Runs the SAME path as the workspace switcher:
  ///   users.activate_workspace_context(...)
  ///   → authoritative context (returned row, or a fresh read)
  ///   → validate entity/role
  ///   → applySelectionContext
  ///
  /// Used for same-workspace ENTITY switching (Business Hub). Returns the
  /// applied authoritative context, or null on failure. The previous context
  /// is hidden while activation is pending and is never restored unverified.
  Future<Map<String, dynamic>?> activateContextRow({
    required String workspaceId,
    required String entityId,
    required String roleId,
    required String activeMode,
    String? businessProfileId,
  }) async {
    final session = ref.read(sessionProvider);
    final userId = session is AuthenticatedSession ? session.userId : null;
    final profileId = session is AuthenticatedSession
        ? session.profile?['id']?.toString()
        : null;
    if (userId == null ||
        userId.isEmpty ||
        profileId == null ||
        profileId.isEmpty) {
      return null;
    }
    final generation = beginSelectionOperation(
      userId: userId,
      profileId: profileId,
    );
    if (generation < 0) return null;
    if (!markSelectionPending(
      generation: generation,
      userId: userId,
      profileId: profileId,
    )) {
      return null;
    }

    final authService = ref.read(authServiceProvider);

    Map<String, dynamic>? activated;
    try {
      activated = await authService.activateWorkspaceContext(
        workspaceId: workspaceId,
        entityId: entityId,
        roleId: roleId,
        businessProfileId: businessProfileId,
      );
    } catch (e) {
      debugPrint('[ContextActivate] activation failed: $e');
      if (selectionOperationIsCurrent(
        generation: generation,
        userId: userId,
        profileId: profileId,
      )) {
        await init();
      }
      return null;
    }

    Map<String, dynamic>? authoritative = activated;
    if (authoritative == null) {
      try {
        authoritative = await sync.fetchUserContext();
      } catch (e) {
        debugPrint('[ContextActivate] authoritative re-read failed: $e');
        authoritative = null;
      }
    }
    if (!selectionOperationIsCurrent(
          generation: generation,
          userId: userId,
          profileId: profileId,
        )) {
      return null;
    }
    if (authoritative == null) {
      if (selectionOperationIsCurrent(
        generation: generation,
        userId: userId,
        profileId: profileId,
      )) {
        await init();
      }
      return null;
    }

    final activeWorkspaceId = authoritative['workspace_id']?.toString() ??
        authoritative['workspaceId']?.toString();
    final activeProfileId = authoritative['profile_id']?.toString() ??
        authoritative['profileId']?.toString();
    final activeEntityId = authoritative['entity_id']?.toString() ??
        authoritative['entityId']?.toString();
    final activeRoleId = authoritative['role_id']?.toString() ??
        authoritative['roleId']?.toString();
    final resolvedActiveMode = authoritative['active_mode']?.toString() ??
        authoritative['role']?.toString();
    final activeBusinessProfileId =
        authoritative['business_profile_id']?.toString() ??
            authoritative['businessProfileId']?.toString();
    if (activeWorkspaceId == null ||
        activeWorkspaceId.isEmpty ||
        activeProfileId == null ||
        activeProfileId.isEmpty ||
        activeEntityId == null ||
        activeEntityId != entityId ||
        activeRoleId == null ||
        activeRoleId != roleId ||
        activeWorkspaceId != workspaceId ||
        activeProfileId != profileId ||
        activeMode.isEmpty ||
        resolvedActiveMode == null ||
        resolvedActiveMode.isEmpty ||
        resolvedActiveMode != activeMode ||
        activeBusinessProfileId != businessProfileId) {
      debugPrint('[ContextActivate] mismatch — expected workspace=$workspaceId '
          'entity=$entityId role=$roleId mode=$activeMode '
          'businessProfile=$businessProfileId, got workspace=$activeWorkspaceId '
          'entity=$activeEntityId role=$activeRoleId mode=$resolvedActiveMode '
          'businessProfile=$activeBusinessProfileId');
      if (selectionOperationIsCurrent(
        generation: generation,
        userId: userId,
        profileId: profileId,
      )) {
        await init();
      }
      return null;
    }

    final applied = await applySelectionContext(
      userId: userId,
      profileId: activeProfileId,
      activeWorkspaceId: activeWorkspaceId!,
      entityId: activeEntityId,
      roleId: activeRoleId,
      role: resolvedActiveMode!,
      businessProfileId: activeBusinessProfileId,
      expectedGeneration: generation,
    );
    if (!applied) return null;

    return authoritative;
  }

  bool _matchesAuthenticatedIdentity(String userId, String profileId) {
    final session = ref.read(sessionProvider);
    return session is AuthenticatedSession &&
        session.userId == userId &&
        session.profile?['id']?.toString() == profileId &&
        SupabaseService.instance.currentUserId == userId;
  }

  Future<void> switchRole(String role) async {
    _refreshGeneration++;
    state = state.copyWith(
      role: role,
      clearActiveWorkspaceId: true,
      isLoading: false,
    );
    await _persist();
  }

  Future<void> switchEntity(String entityId) async {
    _refreshGeneration++;
    state = state.copyWith(
      entityId: entityId,
      clearActiveWorkspaceId: true,
      isLoading: false,
    );
    await _persist();
  }

  Future<void> logout() async {
    final generation = ++_refreshGeneration;
    await storage.clear();
    if (generation != _refreshGeneration ||
        ref.read(isAuthenticatedProvider) ||
        SupabaseService.instance.currentUserId != null) {
      return;
    }
    state = const EntityContext(isGuest: true, isLoading: false);
    await ref
        .read(activeWorkspaceProvider.notifier)
        .reconcileWithActiveContext(
      isCurrent: () =>
          generation == _refreshGeneration &&
          !ref.read(isAuthenticatedProvider) &&
          SupabaseService.instance.currentUserId == null,
    );
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
