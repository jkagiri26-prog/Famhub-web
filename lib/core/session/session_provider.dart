/// ============================================================
/// SESSION PROVIDER — Application-wide session state
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/session/ = session management layer
///
/// ✅ Responsibilities:
///   - Provide the current AppSession via Riverpod
///   - Restore the Supabase session on every startup
///   - Restore the user profile from users.profiles (source of truth)
///   - Restore workspace selections from users.user_workspaces (source of truth)
///   - Create a profile via the create-profile Edge Function
///   - Save workspace selections via the select-workspaces Edge Function
///   - Expose a distinct failure state (SessionFailure) on restore errors
///
/// ❌ Does NOT:
///   - Contain widget logic
///   - Know about routing or navigation
///
/// 🚫 NO local persistence is used for onboarding state:
///   - profile existence  → users.profiles
///   - workspace selections → users.user_workspaces
///   - default workspace   → users.profiles.current_workspace_id
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:famhub_app/core/services/supabase_service.dart';
import 'package:famhub_app/core/services/auth_service.dart';
import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/features/auth/infrastructure/services/otp_session_storage.dart';
import 'package:famhub_app/features/profile/application/providers/profile_location_provider.dart';

/// ============================================================
/// SESSION CONTROLLER
/// ============================================================
class SessionController extends Notifier<AppSession> {
  final AuthService _authService = AuthService();

  @override
  AppSession build() {
    // Initial state — the SessionGate shows the splash screen until
    // restoration finishes. This MUST NOT look like "unauthenticated"
    // or "no profile" while startup state is still being restored.
    return const InitializingSession();
  }

  /// Initialize the session from Supabase.
  ///
  /// Startup flow:
  ///   1. Restore the Supabase session.
  ///   2. If unauthenticated → UnauthenticatedSession.
  ///   3. Restore the profile from users.profiles.
  ///   4. Restore workspace selections from users.user_workspaces.
  ///   5. Publish an AuthenticatedSession carrying all restored state.
  ///
  /// A database/network error produces a [SessionFailure] — it is NEVER
  /// conflated with "no profile" or "no session".
  Future<SessionStatus> initialize() async {
    final supabase = SupabaseService.instance;
    final session = supabase.currentSession;
    final user = supabase.currentUser;

    debugPrint('[SESSION-DIAG] initialize() ENTER — '
        'session=${session != null} user=${user?.id} '
        'currentState=${state.runtimeType} hasProfile=${state.hasProfile}');

    if (session == null || user == null) {
      state = const UnauthenticatedSession();
      return SessionStatus.unauthenticated;
    }

    try {
      // ── Profile restore (database is the source of truth) ──
      // A throw (RLS / network) is treated like an unreadable profile — the
      // workspace fallback below decides whether the user actually completed
      // onboarding. Never surface a hard error for an onboarded user whose
      // profile row is simply not readable yet.
      Map<String, dynamic>? profile;
      var profileReadFailed = false;
      try {
        profile = await _loadProfile(user.id);
      } on Exception catch (e, st) {
        profileReadFailed = true;
        debugPrint('[SESSION-DIAG] initialize() _loadProfile THREW: $e');
        debugPrintStack(
          stackTrace: st,
          label: '[SESSION-DIAG] initialize/_loadProfile',
          maxFrames: 6,
        );
        profile = null;
      }
      debugPrint('[SESSION-DIAG] initialize() _loadProfile -> '
          '${profile == null ? 'NULL' : 'VALID(id=${profile['id']}, auth_user_id=${profile['auth_user_id']}, current_workspace_id=${profile['current_workspace_id']})'}');

      if (profile == null) {
        // ── RLS safeguard ──
        // The profile row may exist but be unreadable by the authenticated
        // client (users.profiles RLS). Workspace selections are persisted in
        // users.user_workspaces only AFTER the profile exists, so a non-empty
        // selection set proves onboarding completed → route to Dashboard, not
        // Create Profile. (Fix the RLS policies on users.profiles to make the
        // profile row readable; this prevents the re-entry bounce meanwhile.)
        List<String> savedWorkspaceIds;
        try {
          savedWorkspaceIds = await _loadWorkspaceIds(user.id);
        } on Exception catch (e) {
          debugPrint(
              '[SessionController.initialize] workspace restore failed: $e');
          savedWorkspaceIds = const [];
        }

        if (savedWorkspaceIds.isNotEmpty) {
          debugPrint('[SESSION-DIAG] initialize() profile==null but '
              'workspaces=$savedWorkspaceIds → RLS-hidden profile; '
              'publishing hasProfile: TRUE (dashboard)');
          state = AuthenticatedSession(
            userId: user.id,
            displayName: user.email ?? 'User',
            profile: const {},
            hasProfile: true,
            workspaceIds: savedWorkspaceIds,
            defaultWorkspaceId: savedWorkspaceIds.first,
            hasCompletedOnboarding: true,
          );
          return SessionStatus.authenticated;
        }

        // If the profile read failed (not merely absent) and no workspaces
        // were found, we cannot conclude "brand-new user" — surface the
        // restore error so the user can retry.
        if (profileReadFailed) {
          debugPrint('[SESSION-DIAG] initialize() profile read FAILED and no '
              'workspaces → SessionFailure');
          state = SessionFailure(
            message: 'We could not restore your session. '
                'Please check your connection and try again.',
          );
          return SessionStatus.error;
        }

        // Authenticated but no profile row yet → Create Profile.
        debugPrint('[SESSION-DIAG] initialize() profile==null, no workspaces → '
            'publishing AuthenticatedSession(hasProfile: FALSE)');
        state = AuthenticatedSession(
          userId: user.id,
          displayName: user.email ?? 'User',
          hasProfile: false,
        );
        return SessionStatus.authenticated;
      }

      // ── Workspace selections restore ──
      final workspaceIds = await _loadWorkspaceIds(user.id);
      final defaultWorkspaceId =
          profile['current_workspace_id'] as String?;

      debugPrint('[SESSION-DIAG] initialize() profile OK → '
          'publishing AuthenticatedSession(hasProfile: TRUE, workspaceIds=$workspaceIds, default=$defaultWorkspaceId)');
      state = AuthenticatedSession(
        userId: user.id,
        displayName: _buildDisplayName(profile) ??
            user.email ??
            'User',
        profile: profile,
        hasProfile: true,
        workspaceIds: workspaceIds,
        defaultWorkspaceId: defaultWorkspaceId ??
            (workspaceIds.isNotEmpty ? workspaceIds.first : null),
        hasCompletedOnboarding: workspaceIds.isNotEmpty,
      );
      return SessionStatus.authenticated;
    } on Exception catch (e, st) {
      debugPrint('[SESSION-DIAG] initialize() EXCEPTION: $e');
      // Network / database error — do NOT treat as a brand-new user.
      // The UI exposes a retry/error state via SessionFailure.
      debugPrint('[SessionController.initialize] error: $e');
      debugPrintStack(
        stackTrace: st,
        label: '[SessionController.initialize]',
        maxFrames: 6,
      );
      state = SessionFailure(
        message: 'We could not restore your session. '
            'Please check your connection and try again.',
      );
      return SessionStatus.error;
    }
  }

  /// Refresh session state (called after auth operations complete).
  Future<SessionStatus> refresh() async {
    debugPrint('[SESSION-DIAG] refresh() CALLED');
    final status = await initialize();
    debugPrint('[SESSION-DIAG] refresh() -> status=$status '
        'state=${state.runtimeType} hasProfile=${state.hasProfile} '
        'workspaceIds=${state.workspaceIds}');
    return status;
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (_) {
      // Continue resetting local state even if remote sign-out fails.
    }
    await OtpSessionStorage.clearSession();
    state = const UnauthenticatedSession();
  }

  /// ============================================================
  /// PROFILE MANAGEMENT
  /// ============================================================

  /// Create a profile for the authenticated user.
  /// Calls the `create-profile` Edge Function — NO direct DB writes.
  ///
  /// On success the provider re-fetches the authoritative profile row
  /// from users.profiles and publishes it. The user is NOT considered
  /// fully onboarded merely because the profile exists — workspace
  /// selections are still required before the dashboard is shown.
  Future<ProfileResult> createProfile({
    required String firstName,
    required String countryId,
    required String phone,
    required List<SelectedLocationEntry> locationLevels,
  }) async {
    final current = state;
    if (current is! AuthenticatedSession) {
      return const ProfileResult(
        success: false,
        error: 'You must be signed in to create a profile.',
      );
    }

    // Build location IDs per level
    String? level2, level3, level4, level5, level6, level7;
    for (var i = 0; i < locationLevels.length && i < 6; i++) {
      final num = i + 2;
      switch (num) {
        case 2: level2 = locationLevels[i].locationId; break;
        case 3: level3 = locationLevels[i].locationId; break;
        case 4: level4 = locationLevels[i].locationId; break;
        case 5: level5 = locationLevels[i].locationId; break;
        case 6: level6 = locationLevels[i].locationId; break;
        case 7: level7 = locationLevels[i].locationId; break;
      }
    }

    final result = await _authService.createProfile(
      firstName: firstName,
      // last_name is required by the Edge Function but not yet collected
      // from the user. Passing an empty string is safe; the backend
      // treats missing/empty strings gracefully.
      lastName: '',
      countryId: countryId,
      phone: phone,
      level2LocationId: level2,
      level3LocationId: level3,
      level4LocationId: level4,
      level5LocationId: level5,
      level6LocationId: level6,
      level7LocationId: level7,
    );

    if (!result.success) {
      return result;
    }

    // ── Persisted-state update ──
    // Re-fetch the profile from the backend (source of truth) so the
    // session carries the authoritative row (is_complete, id, etc.).
    final userId = current.userId;
    try {
      final profile = userId != null ? await _loadProfile(userId) : null;
      debugPrint('[SESSION-DIAG] createProfile _loadProfile -> '
          '${profile == null ? 'NULL' : 'VALID'}');
      final firstNameFromProfile =
          result.profile?['first_name'] as String? ?? firstName.trim();

      // A fresh profile has no workspace selections yet.
      final workspaceIds = await _loadWorkspaceIds(userId ?? '');

      debugPrint('[SESSION-DIAG] createProfile publishing AuthenticatedSession('
          'hasProfile: true, workspaceIds=$workspaceIds)');
      state = current.copyWith(
        displayName: firstNameFromProfile,
        hasProfile: true,
        profile: profile ?? Map<String, dynamic>.from(result.profile!),
        workspaceIds: workspaceIds,
        hasCompletedOnboarding: workspaceIds.isNotEmpty,
        clearDefaultWorkspaceId: true,
      );
    } on Exception catch (e) {
      debugPrint('[createProfile] state refresh failed: $e');
      debugPrint('[SESSION-DIAG] createProfile CATCH — _loadProfile/_loadWorkspaceIds '
          'threw: $e; publishing hasProfile: true from echoed profile');
      // The profile was created on the backend; still mark the session
      // as having a profile so the user can continue onboarding.
      state = current.copyWith(
        displayName: firstName.trim(),
        hasProfile: true,
        profile: Map<String, dynamic>.from(result.profile!),
        workspaceIds: const [],
        hasCompletedOnboarding: false,
        clearDefaultWorkspaceId: true,
      );
    }

    return result;
  }

  /// ============================================================
  /// WORKSPACE SELECTION MANAGEMENT
  /// ============================================================

  /// Persist the selected workspaces via the `select-workspaces` Edge
  /// Function and update the session with the backend's response
  /// (workspace IDs + default workspace).
  ///
  /// The session state MUST be an [AuthenticatedSession] before saving.
  /// If it is not, we never silently drop the user's selection: we log the
  /// actual state and surface the failure to the UI.
  Future<WorkspaceSelectionResult> selectWorkspaces(
    List<String> workspaces,
  ) async {
    final current = state;
    debugPrint('[SESSION-DIAG] selectWorkspaces ENTER — '
        'state=${current.runtimeType} hasProfile=${current.hasProfile} '
        'workspaceIds=${current.workspaceIds} selected=$workspaces');
    if (current is! AuthenticatedSession) {
      debugPrint('[SessionController.selectWorkspaces] ABORT: state is not an '
          'AuthenticatedSession. Actual state: ${current.runtimeType} '
          '(status: ${current.status}). Workspaces were NOT persisted and the '
          'selection is preserved in the UI.');
      return const WorkspaceSelectionResult(
        success: false,
        error: 'Your session is not active. Please refresh the app and try again.',
      );
    }

    final result = await _authService.selectWorkspaces(
      workspaceIds: workspaces,
    );
    if (!result.success) {
      debugPrint('[SessionController.selectWorkspaces] Edge Function failed: '
          '${result.error}');
      return result;
    }

    final persistedIds =
        result.workspaceIds.isNotEmpty ? result.workspaceIds : workspaces;
    final defaultWorkspaceId = result.defaultWorkspaceId ??
        (persistedIds.isNotEmpty ? persistedIds.first : null);

    // The Edge Function persisted the selections. Re-fetch the authoritative
    // profile row (is_complete / current_workspace_id were updated server-side)
    // and publish it alongside the workspace state so the database remains the
    // source of truth. Fall back to the profile echoed by the response.
    Map<String, dynamic>? profile = result.profile ?? current.profile;
    try {
      final userId = current.userId;
      if (userId != null) {
        final fresh = await _loadProfile(userId);
        if (fresh != null) profile = fresh;
      }
    } on Exception catch (e, st) {
      debugPrint('[SessionController.selectWorkspaces] profile refresh failed: $e');
      debugPrintStack(
        stackTrace: st,
        label: '[SessionController.selectWorkspaces]',
        maxFrames: 4,
      );
    }

    debugPrint('[SESSION-DIAG] selectWorkspaces publishing state — '
        'hasProfile=${current.hasProfile} (unchanged), '
        'workspaceIds=$persistedIds, default=$defaultWorkspaceId, '
        'hasCompletedOnboarding=${persistedIds.isNotEmpty}, '
        'profile=${profile == null ? 'NULL' : 'VALID'}');
    state = current.copyWith(
      selectedRoles: persistedIds,
      profile: profile,
      workspaceIds: persistedIds,
      defaultWorkspaceId: defaultWorkspaceId,
      hasCompletedOnboarding: persistedIds.isNotEmpty,
    );

    return WorkspaceSelectionResult(
      success: true,
      workspaceIds: persistedIds,
      defaultWorkspaceId: defaultWorkspaceId,
      workspaces: result.workspaces,
      profile: profile,
    );
  }

  /// ============================================================
  /// RESTORE HELPERS
  /// ============================================================

  /// Query the authoritative profile row for the user.
  Future<Map<String, dynamic>?> _loadProfile(String userId) async {
    debugPrint('[SESSION-DIAG] _loadProfile(userId=$userId) querying users.profiles '
        'via AUTHENTICATED client...');
    try {
      final response = await SupabaseService.instance
          .from('profiles', schema: 'users')
          .select()
          .eq('auth_user_id', userId)
          .maybeSingle();
      if (response == null) {
        debugPrint('[SESSION-DIAG] _loadProfile -> NULL (0 rows returned)');
        return null;
      }
      debugPrint('[SESSION-DIAG] _loadProfile -> VALID row: ${Map<String, dynamic>.from(response).toString()}');
      return Map<String, dynamic>.from(response);
    } catch (e, st) {
      debugPrint('[SESSION-DIAG] _loadProfile -> EXCEPTION: $e');
      debugPrintStack(
        stackTrace: st,
        label: '[SESSION-DIAG] _loadProfile',
        maxFrames: 8,
      );
      rethrow;
    }
  }

  /// Query the persisted workspace selections for the user.
  /// Source of truth: users.user_workspaces.
  Future<List<String>> _loadWorkspaceIds(String userId) async {
    if (userId.isEmpty) return const [];
    final response = await SupabaseService.instance
        .from('user_workspaces', schema: 'users')
        .select('workspace_id')
        .eq('auth_user_id', userId);
    final rows = response as List;
    final ids = <String>[];
    for (final row in rows) {
      if (row is Map) {
        final id = row['workspace_id']?.toString();
        if (id != null && id.isNotEmpty && !ids.contains(id)) {
          ids.add(id);
        }
      }
    }
    return ids;
  }

  /// Build a display name from the profile row, preferring
  /// first/middle/last name columns.
  String? _buildDisplayName(Map<String, dynamic> profile) {
    final first = profile['first_name']?.toString();
    final middle = profile['middle_name']?.toString();
    final last = profile['last_name']?.toString();
    final parts = <String>[
      if (first != null && first.isNotEmpty) first,
      if (middle != null && middle.isNotEmpty) middle,
      if (last != null && last.isNotEmpty) last,
    ];
    if (parts.isNotEmpty) return parts.join(' ');
    return null;
  }
}

/// ============================================================
/// PROVIDERS
/// ============================================================

final sessionProvider =
    NotifierProvider<SessionController, AppSession>(
  SessionController.new,
);

/// Current session status
final sessionStatusProvider = Provider<SessionStatus>((ref) {
  return ref.watch(sessionProvider).status;
});

/// Whether the user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).isAuthenticated;
});

/// Whether the user has a profile
final hasProfileProvider = Provider<bool>((ref) {
  final session = ref.watch(sessionProvider);
  if (session is AuthenticatedSession) {
    return session.hasProfile;
  }
  return false;
});

/// Whether onboarding (workspace selection) is complete
final hasOnboardingCompletedProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider).hasCompletedOnboarding;
});

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});
